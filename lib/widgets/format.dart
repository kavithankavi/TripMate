import 'package:intl/intl.dart';

import '../models/trip.dart';

final _dateTime = DateFormat('d MMM yyyy, HH:mm');

String fmtDateTime(DateTime d) => _dateTime.format(d);

String fmtDuration(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
  final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
  return '${h.toString().padLeft(2, '0')}:$m:$s';
}

String fmtKm(double meters) => '${(meters / 1000).toStringAsFixed(2)} km';
String fmtSpeed(double kmh) => '${kmh.toStringAsFixed(1)} km/h';
String fmtAlt(double? m) => m == null ? '-' : '${m.toStringAsFixed(0)} m';
String fmtCoord(double? v) => v == null ? '-' : v.toStringAsFixed(5);

String fmtPlace(String? address, double? lat, double? lng) {
  if (lat == null || lng == null) return 'Not recorded';
  final coords = '${fmtCoord(lat)}, ${fmtCoord(lng)}';
  return address == null ? coords : '$address\n$coords';
}

String tripTitle(Trip t) => '${t.name} · ${fmtDateTime(t.startTime)}';
