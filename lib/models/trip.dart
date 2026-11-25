class Trip {
  Trip({
    this.id,
    required this.name,
    required this.startTime,
    this.endTime,
    this.startLat,
    this.startLng,
    this.endLat,
    this.endLng,
    this.startAddress,
    this.endAddress,
    this.distanceM = 0,
    this.maxSpeedKmh = 0,
    this.avgSpeedKmh = 0,
    this.maxAltitudeM,
  });

  int? id;
  String name;
  DateTime startTime;
  DateTime? endTime;
  double? startLat, startLng, endLat, endLng;
  String? startAddress, endAddress;
  double distanceM;
  double maxSpeedKmh;
  double avgSpeedKmh;
  double? maxAltitudeM;

  bool get isFinished => endTime != null;
  Duration get duration => (endTime ?? DateTime.now()).difference(startTime);

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'name': name,
        'start_time': startTime.millisecondsSinceEpoch,
        'end_time': endTime?.millisecondsSinceEpoch,
        'start_lat': startLat,
        'start_lng': startLng,
        'end_lat': endLat,
        'end_lng': endLng,
        'start_address': startAddress,
        'end_address': endAddress,
        'distance_m': distanceM,
        'max_speed_kmh': maxSpeedKmh,
        'avg_speed_kmh': avgSpeedKmh,
        'max_altitude_m': maxAltitudeM,
      };

  static Trip fromMap(Map<String, Object?> m) => Trip(
        id: m['id'] as int?,
        name: m['name'] as String,
        startTime:
            DateTime.fromMillisecondsSinceEpoch(m['start_time'] as int),
        endTime: m['end_time'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(m['end_time'] as int),
        startLat: (m['start_lat'] as num?)?.toDouble(),
        startLng: (m['start_lng'] as num?)?.toDouble(),
        endLat: (m['end_lat'] as num?)?.toDouble(),
        endLng: (m['end_lng'] as num?)?.toDouble(),
        startAddress: m['start_address'] as String?,
        endAddress: m['end_address'] as String?,
        distanceM: (m['distance_m'] as num?)?.toDouble() ?? 0,
        maxSpeedKmh: (m['max_speed_kmh'] as num?)?.toDouble() ?? 0,
        avgSpeedKmh: (m['avg_speed_kmh'] as num?)?.toDouble() ?? 0,
        maxAltitudeM: (m['max_altitude_m'] as num?)?.toDouble(),
      );
}

class TrackPoint {
  TrackPoint({
    required this.time,
    required this.lat,
    required this.lng,
    required this.altitudeM,
    required this.speedKmh,
  });

  final DateTime time;
  final double lat, lng, altitudeM, speedKmh;

  Map<String, Object?> toMap(int tripId) => {
        'trip_id': tripId,
        'time': time.millisecondsSinceEpoch,
        'lat': lat,
        'lng': lng,
        'alt': altitudeM,
        'speed_kmh': speedKmh,
      };

  static TrackPoint fromMap(Map<String, Object?> m) => TrackPoint(
        time: DateTime.fromMillisecondsSinceEpoch(m['time'] as int),
        lat: (m['lat'] as num).toDouble(),
        lng: (m['lng'] as num).toDouble(),
        altitudeM: (m['alt'] as num).toDouble(),
        speedKmh: (m['speed_kmh'] as num).toDouble(),
      );
}
