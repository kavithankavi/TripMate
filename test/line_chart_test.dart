import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:tripmate/widgets/line_chart.dart';

void main() {
  test('nice axis range uses round steps', () {
    final r = AxisRange.nice(0, 87);
    expect(r.min, 0);
    expect(r.step, 25);
    expect(r.max, 100);
    final flat = AxisRange.nice(50, 50);
    expect(flat.max, greaterThan(flat.min));
  });

  test('time labels', () {
    expect(fmtChartTime(const Duration(minutes: 4, seconds: 5)), '4:05');
    expect(fmtChartTime(const Duration(hours: 1, minutes: 7)), '1:07 h');
  });

  test('downsampling keeps the peak', () {
    final pts = [
      for (var i = 0; i < 3000; i++)
        ChartPoint(Duration(seconds: i * 3), i == 1234 ? 140.0 : 50.0)
    ];
    final small = downsample(pts, 300);
    expect(small.length, lessThanOrEqualTo(600));
    expect(small.map((p) => p.value), contains(140.0));
  });

  testWidgets('chart renders, and shows a note without data', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Column(children: [
          TripLineChart(
            points: [
              for (var i = 0; i < 100; i++)
                ChartPoint(Duration(seconds: i * 3), (i % 20) * 4.0)
            ],
            total: const Duration(seconds: 300),
            reference: 38,
            referenceLabel: 'Avg 38.0 km/h',
            startAtZero: true,
          ),
          const TripLineChart(
              points: [], total: Duration(minutes: 1)),
        ]),
      ),
    ));
    expect(find.byType(CustomPaint), findsWidgets);
    expect(find.text('Not enough data recorded for a graph.'), findsOneWidget);
  });
}
