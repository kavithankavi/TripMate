import 'dart:async';
import 'dart:io' show Platform;

import 'package:battery_plus/battery_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../config.dart';
import '../data/trip_database.dart';
import '../models/trip.dart';
import 'sampling.dart';

class TrackingException implements Exception {
  TrackingException(this.message);
  final String message;
  @override
  String toString() => message;
}

sealed class TrackerEvent {}

class LowBatteryEvent extends TrackerEvent {
  LowBatteryEvent(this.level);
  final int level;
}

class AutoStoppedEvent extends TrackerEvent {
  AutoStoppedEvent(this.trip);
  final Trip trip;
}

/// Records a trip: samples the location every 3 s (10 s below 30% battery),
/// keeps running in the background through a foreground service on Android
/// and background location updates on iOS, and stops after 2 h idle.
class TripTracker extends ChangeNotifier {
  TripTracker(this._db);

  final TripDatabase _db;
  final Battery _battery = Battery();
  final _events = StreamController<TrackerEvent>.broadcast();

  Stream<TrackerEvent> get events => _events.stream;

  Trip? _trip;
  TrackPoint? _last;
  final List<LatLng> _route = [];
  Duration _interval = AppConfig.sampleInterval;
  int? _batteryLevel;
  bool _lowBatteryAlerted = false;
  DateTime? _lastAccepted;
  DateTime? _lastMovement;
  LatLng? _idleAnchor;

  StreamSubscription<Position>? _positionSub;
  StreamSubscription<BatteryState>? _batteryStateSub;
  Timer? _ticker;
  Timer? _batteryTimer;
  bool _stopping = false;

  bool get isTracking => _trip != null;
  Trip? get trip => _trip;
  TrackPoint? get lastPoint => _last;
  List<LatLng> get route => List.unmodifiable(_route);
  Duration get interval => _interval;
  int? get batteryLevel => _batteryLevel;
  Duration get elapsed =>
      _trip == null ? Duration.zero : DateTime.now().difference(_trip!.startTime);

  /// Closes trips left open if the app was killed during a trip.
  Future<void> recoverUnfinished() async {
    for (final t in await _db.unfinishedTrips()) {
      final pts = await _db.points(t.id!);
      if (pts.isEmpty) {
        await _db.deleteTrip(t.id!);
        continue;
      }
      t.endTime = pts.last.time;
      t.endLat = pts.last.lat;
      t.endLng = pts.last.lng;
      _finishStats(t);
      await _db.updateTrip(t);
    }
    await _db.pruneOldTrips();
  }

  Future<String> defaultTripName(DateTime start) async {
    final n = await _db.tripCount() + 1;
    return 'Trip$n';
  }

  /// Checks services and permission. Throws [TrackingException] with a
  /// user-friendly message when location can't be used.
  Future<void> ensurePermission() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw TrackingException(
          'Location is turned off. Please enable location services.');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied) {
      throw TrackingException('TripMate needs location access to record trips.');
    }
    if (perm == LocationPermission.deniedForever) {
      throw TrackingException(
          'Location access is blocked. Please allow it in Settings.');
    }
  }

  Future<void> start(String name) async {
    if (isTracking) return;
    await ensurePermission();

    final now = DateTime.now();
    final trip = Trip(name: name, startTime: now);
    trip.id = await _db.insertTrip(trip);
    _trip = trip;
    _route.clear();
    _last = null;
    _lastAccepted = null;
    _lastMovement = now;
    _idleAnchor = null;
    _lowBatteryAlerted = false;

    await _checkBattery();
    _listenPositions();
    _batteryStateSub =
        _battery.onBatteryStateChanged.listen((_) => _checkBattery());
    _batteryTimer =
        Timer.periodic(const Duration(minutes: 1), (_) => _checkBattery());
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _checkIdle();
      notifyListeners();
    });
    notifyListeners();
  }

  LocationSettings _settings() {
    if (!kIsWeb && Platform.isAndroid) {
      return AndroidSettings(
        accuracy: LocationAccuracy.high,
        distanceFilter: 0,
        // GPS fixes arrive every second and are thinned in _onPosition to
        // 3 s (or 10 s on low battery), so both rates are exact.
        intervalDuration: const Duration(seconds: 1),
        foregroundNotificationConfig: const ForegroundNotificationConfig(
          notificationTitle: 'TripMate is recording your trip',
          notificationText: 'Tap to open. Stop the trip in the app.',
          notificationChannelName: 'Trip recording',
          notificationIcon:
              AndroidResource(name: 'ic_notification', defType: 'drawable'),
          setOngoing: true,
        ),
      );
    }
    if (!kIsWeb && Platform.isIOS) {
      return AppleSettings(
        accuracy: LocationAccuracy.bestForNavigation,
        activityType: ActivityType.automotiveNavigation,
        distanceFilter: 0,
        pauseLocationUpdatesAutomatically: false,
        allowBackgroundLocationUpdates: true,
        showBackgroundLocationIndicator: true,
      );
    }
    return const LocationSettings(accuracy: LocationAccuracy.high);
  }

  void _listenPositions() {
    _positionSub?.cancel();
    _positionSub = Geolocator.getPositionStream(locationSettings: _settings())
        .listen(_onPosition, onError: (Object e) {
      debugPrint('Location error: $e');
    });
  }

  Future<void> _onPosition(Position p) async {
    final trip = _trip;
    if (trip == null) return;
    final now = p.timestamp;

    // Keep one sample per interval (3 s, or 10 s on low battery).
    // Both platforms deliver a fix about every second. The small tolerance
    // absorbs timing jitter so a fix that is due is not skipped.
    if (!isSampleDue(_lastAccepted, now, _interval)) return;
    _lastAccepted = now;

    final prev = _last;
    var speedKmh = p.speed >= 0 ? p.speed * 3.6 : 0.0;
    double step = 0;
    if (prev != null) {
      step = Geolocator.distanceBetween(prev.lat, prev.lng, p.latitude, p.longitude);
      // Ignore GPS jitter while standing still.
      if (step < 5 || step < p.accuracy * 0.5) step = 0;
      if (p.speed < 0) {
        final secs = now.difference(prev.time).inMilliseconds / 1000;
        if (secs > 0) speedKmh = step / secs * 3.6;
      }
    }

    final pt = TrackPoint(
      time: now,
      lat: p.latitude,
      lng: p.longitude,
      altitudeM: p.altitude,
      speedKmh: speedKmh,
    );
    _last = pt;
    _route.add(LatLng(pt.lat, pt.lng));

    trip.startLat ??= pt.lat;
    trip.startLng ??= pt.lng;
    trip.endLat = pt.lat;
    trip.endLng = pt.lng;
    trip.distanceM += step;
    if (speedKmh > trip.maxSpeedKmh) trip.maxSpeedKmh = speedKmh;
    if (trip.maxAltitudeM == null || pt.altitudeM > trip.maxAltitudeM!) {
      trip.maxAltitudeM = pt.altitudeM;
    }

    // Movement detection for the idle auto-stop.
    final here = LatLng(pt.lat, pt.lng);
    final anchor = _idleAnchor;
    final movedFromAnchor = anchor == null ||
        Geolocator.distanceBetween(
                anchor.latitude, anchor.longitude, pt.lat, pt.lng) >
            50;
    if (speedKmh >= 3 || movedFromAnchor) {
      _lastMovement = now;
      _idleAnchor = here;
    }

    notifyListeners();
    await _db.insertPoint(trip.id!, pt);
    if (!identical(_trip, trip) || _stopping) return;
    await _db.updateTrip(trip);
    _checkIdle();
  }

  void _checkIdle() {
    final lm = _lastMovement;
    if (lm != null &&
        DateTime.now().difference(lm) > AppConfig.idleAutoStop &&
        !_stopping) {
      stop(auto: true);
    }
  }

  Future<void> _checkBattery() async {
    int level;
    try {
      level = await _battery.batteryLevel;
    } catch (_) {
      return;
    }
    _batteryLevel = level;
    final low = level < AppConfig.lowBatteryThreshold;
    final wanted = sampleIntervalFor(level);
    if (low && !_lowBatteryAlerted && isTracking) {
      _lowBatteryAlerted = true;
      _events.add(LowBatteryEvent(level));
    }
    if (!low) _lowBatteryAlerted = false;
    // The position stream keeps running at 1 s and samples are thinned in
    // _onPosition. Restarting the stream would restart the Android
    // foreground service, which Android 12+ blocks from the background.
    _interval = wanted;
    notifyListeners();
  }

  /// Stops the trip, saves it and returns it.
  /// When [auto] is true the end time is the last moment of movement,
  /// so the 2 h of idle time does not lower the average speed.
  Future<Trip?> stop({bool auto = false}) async {
    final trip = _trip;
    if (trip == null || _stopping) return null;
    _stopping = true;
    await _positionSub?.cancel();
    await _batteryStateSub?.cancel();
    _ticker?.cancel();
    _batteryTimer?.cancel();
    _positionSub = null;

    trip.endTime = auto ? (_lastMovement ?? DateTime.now()) : DateTime.now();
    _finishStats(trip);
    trip.startAddress = await _address(trip.startLat, trip.startLng);
    trip.endAddress = await _address(trip.endLat, trip.endLng);
    await _db.updateTrip(trip);
    await _db.pruneOldTrips();

    _trip = null;
    _stopping = false;
    _interval = AppConfig.sampleInterval;
    notifyListeners();
    if (auto) _events.add(AutoStoppedEvent(trip));
    return trip;
  }

  void _finishStats(Trip t) {
    final hours = t.duration.inMilliseconds / 3600000;
    t.avgSpeedKmh = hours > 0 ? (t.distanceM / 1000) / hours : 0;
  }

  Future<String?> _address(double? lat, double? lng) async {
    if (lat == null || lng == null) return null;
    try {
      final list = await Geocoding().placemarkFromCoordinates(lat, lng)
          .timeout(const Duration(seconds: 8));
      if (list.isEmpty) return null;
      final pm = list.first;
      final parts = <String?>[pm.street, pm.locality, pm.administrativeArea]
          .whereType<String>()
          .where((s) => s.trim().isNotEmpty)
          .toSet()
          .toList();
      return parts.isEmpty ? null : parts.join(', ');
    } catch (_) {
      return null; // Offline or no geocoder: the UI shows coordinates.
    }
  }

  @override
  void dispose() {
    _positionSub?.cancel();
    _batteryStateSub?.cancel();
    _ticker?.cancel();
    _batteryTimer?.cancel();
    _events.close();
    super.dispose();
  }
}
