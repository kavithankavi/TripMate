import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/widgets/format.dart';

void main() {
  test('duration is formatted as hh:mm:ss', () {
    expect(fmtDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
        '01:02:03');
  });

  test('distance and speed formatting', () {
    expect(fmtKm(12345), '12.35 km');
    expect(fmtSpeed(42.26), '42.3 km/h');
    expect(fmtAlt(null), '-');
  });

  test('place falls back to coordinates', () {
    expect(fmtPlace(null, 12.9716, 77.5946), '12.97160, 77.59460');
    expect(fmtPlace(null, null, null), 'Not recorded');
  });
}
