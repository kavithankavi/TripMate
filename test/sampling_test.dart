import 'package:flutter_test/flutter_test.dart';
import 'package:tripmate/services/sampling.dart';

void main() {
  test('3 s normally, 10 s below 30% battery', () {
    expect(sampleIntervalFor(100), const Duration(seconds: 3));
    expect(sampleIntervalFor(30), const Duration(seconds: 3));
    expect(sampleIntervalFor(29), const Duration(seconds: 10));
    expect(sampleIntervalFor(5), const Duration(seconds: 10));
  });

  List<int> savedSeconds(Duration interval) {
    // Fixes arrive every second with a little jitter, for one minute.
    final t0 = DateTime(2026, 1, 1);
    DateTime? last;
    final saved = <int>[];
    for (var s = 0; s <= 60; s++) {
      final now = t0.add(Duration(seconds: s, milliseconds: s.isEven ? 40 : -40));
      if (isSampleDue(last, now, interval)) {
        last = now;
        saved.add(s);
      }
    }
    return saved;
  }

  test('1 s fixes are thinned to every 3 s', () {
    expect(savedSeconds(const Duration(seconds: 3)),
        [for (var s = 0; s <= 60; s += 3) s]);
  });

  test('1 s fixes are thinned to every 10 s on low battery', () {
    expect(savedSeconds(const Duration(seconds: 10)),
        [0, 10, 20, 30, 40, 50, 60]);
  });
}
