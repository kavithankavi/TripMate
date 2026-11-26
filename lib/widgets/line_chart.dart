import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// One value at [t] after the start of the trip.
class ChartPoint {
  const ChartPoint(this.t, this.value);
  final Duration t;
  final double value;
}

/// A simple line chart over the whole trip, drawn with a CustomPainter so no
/// chart package is needed. The x axis runs from the trip start to [total].
/// An optional [reference] value (for example the average speed) is drawn as
/// a dashed horizontal line with [referenceLabel].
class TripLineChart extends StatelessWidget {
  const TripLineChart({
    super.key,
    required this.points,
    required this.total,
    this.color = AppColors.primary,
    this.reference,
    this.referenceLabel,
    this.startAtZero = false,
    this.height = 180,
  });

  final List<ChartPoint> points;
  final Duration total;
  final Color color;
  final double? reference;
  final String? referenceLabel;

  /// Start the y axis at 0 (speed) instead of near the lowest value (altitude).
  final bool startAtZero;
  final double height;

  @override
  Widget build(BuildContext context) {
    if (points.length < 2) {
      return SizedBox(
        height: height,
        child: const Center(
          child: Text('Not enough data recorded for a graph.',
              style: TextStyle(color: AppColors.muted)),
        ),
      );
    }
    return SizedBox(
      height: height,
      width: double.infinity,
      child: CustomPaint(
        painter: _ChartPainter(
          points: points,
          total: total,
          color: color,
          reference: reference,
          referenceLabel: referenceLabel,
          startAtZero: startAtZero,
        ),
      ),
    );
  }
}

/// Axis range with "nice" round tick steps (1, 2, 2.5 or 5 x 10^n).
class AxisRange {
  AxisRange(this.min, this.max, this.step);
  final double min, max, step;

  static AxisRange nice(double lo, double hi, {int ticks = 4}) {
    if (hi < lo) {
      final t = lo;
      lo = hi;
      hi = t;
    }
    if (hi - lo < 1e-6) {
      lo -= 1;
      hi += 1;
    }
    final raw = (hi - lo) / ticks;
    final mag = math.pow(10, (math.log(raw) / math.ln10).floor()).toDouble();
    final step = [1.0, 2.0, 2.5, 5.0, 10.0]
            .map((m) => m * mag)
            .firstWhere((s) => s >= raw, orElse: () => 10 * mag);
    return AxisRange((lo / step).floor() * step, (hi / step).ceil() * step, step);
  }
}

/// Elapsed-time axis label: "0:45" (m:ss) under an hour, "1:05 h" above.
String fmtChartTime(Duration d) {
  if (d.inHours >= 1) {
    return '${d.inHours}:${d.inMinutes.remainder(60).toString().padLeft(2, '0')} h';
  }
  return '${d.inMinutes}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';
}

/// Reduces [points] to at most about [buckets] x 2 points, keeping the lowest
/// and highest value of each time bucket so peaks (max speed) stay visible.
List<ChartPoint> downsample(List<ChartPoint> points, int buckets) {
  if (points.length <= buckets * 2 || buckets < 1) return points;
  final out = <ChartPoint>[];
  final per = points.length / buckets;
  for (var b = 0; b < buckets; b++) {
    final from = (b * per).floor();
    final to = math.min(points.length, ((b + 1) * per).floor());
    if (from >= to) continue;
    var lo = points[from], hi = points[from];
    for (var i = from + 1; i < to; i++) {
      if (points[i].value < lo.value) lo = points[i];
      if (points[i].value > hi.value) hi = points[i];
    }
    if (identical(lo, hi)) {
      out.add(lo);
    } else if (lo.t <= hi.t) {
      out..add(lo)..add(hi);
    } else {
      out..add(hi)..add(lo);
    }
  }
  return out;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.total,
    required this.color,
    required this.reference,
    required this.referenceLabel,
    required this.startAtZero,
  });

  final List<ChartPoint> points;
  final Duration total;
  final Color color;
  final double? reference;
  final String? referenceLabel;
  final bool startAtZero;

  static const _labelStyle = TextStyle(color: AppColors.muted, fontSize: 10);
  static const double _left = 40, _bottom = 20, _top = 8, _right = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = Rect.fromLTRB(_left, _top, size.width - _right, size.height - _bottom);
    if (plot.width <= 0 || plot.height <= 0) return;

    var lo = points.map((p) => p.value).reduce(math.min);
    var hi = points.map((p) => p.value).reduce(math.max);
    if (reference != null) {
      lo = math.min(lo, reference!);
      hi = math.max(hi, reference!);
    }
    if (startAtZero) lo = math.min(0, lo);
    final y = AxisRange.nice(lo, hi);
    final totalMs = math.max(1, total.inMilliseconds).toDouble();

    double px(Duration t) =>
        plot.left + plot.width * (t.inMilliseconds / totalMs).clamp(0.0, 1.0);
    double py(double v) =>
        plot.bottom - plot.height * ((v - y.min) / (y.max - y.min));

    // Horizontal grid and y labels.
    final grid = Paint()
      ..color = const Color(0xFFE1E8E7)
      ..strokeWidth = 1;
    for (var v = y.min; v <= y.max + y.step / 2; v += y.step) {
      final yy = py(v);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
      _text(canvas, _num(v, y.step), Offset(plot.left - 4, yy),
          align: _Align.rightMiddle);
    }

    // Time labels: start, middle, end.
    for (final f in [0.0, 0.5, 1.0]) {
      final t = Duration(milliseconds: (totalMs * f).round());
      final align = f == 0
          ? _Align.leftTop
          : f == 1
              ? _Align.rightTop
              : _Align.centerTop;
      _text(canvas, fmtChartTime(t), Offset(px(t), plot.bottom + 4), align: align);
    }

    // The line, with a soft fill below it.
    final pts = downsample(points, plot.width.round());
    final line = Path()..moveTo(px(pts.first.t), py(pts.first.value));
    for (final p in pts.skip(1)) {
      line.lineTo(px(p.t), py(p.value));
    }
    final fill = Path.from(line)
      ..lineTo(px(pts.last.t), plot.bottom)
      ..lineTo(px(pts.first.t), plot.bottom)
      ..close();
    canvas.save();
    canvas.clipRect(plot.inflate(2));
    canvas.drawPath(
        fill,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [color.withValues(alpha: 0.28), color.withValues(alpha: 0.02)],
          ).createShader(plot));
    canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke
          ..strokeJoin = StrokeJoin.round);
    canvas.restore();

    // Reference (average) line, dashed.
    final ref = reference;
    if (ref != null) {
      final yy = py(ref);
      final dash = Paint()
        ..color = AppColors.danger
        ..strokeWidth = 1.6;
      for (var x = plot.left; x < plot.right; x += 9) {
        canvas.drawLine(
            Offset(x, yy), Offset(math.min(x + 5, plot.right), yy), dash);
      }
      if (referenceLabel != null) {
        final nearTop = yy - plot.top < 16;
        _text(canvas, referenceLabel!,
            Offset(plot.right - 2, nearTop ? yy + 3 : yy - 3),
            align: nearTop ? _Align.rightTop : _Align.rightBottom,
            style: const TextStyle(
                color: AppColors.danger,
                fontSize: 11,
                fontWeight: FontWeight.w600,
                backgroundColor: Color(0xCCFFFFFF)));
      }
    }
  }

  String _num(double v, double step) =>
      v.toStringAsFixed(step < 1 ? 1 : 0);

  void _text(Canvas canvas, String s, Offset at,
      {required _Align align, TextStyle style = _labelStyle}) {
    final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr)
      ..layout();
    final dx = switch (align) {
      _Align.leftTop => 0.0,
      _Align.centerTop => -tp.width / 2,
      _Align.rightTop || _Align.rightMiddle || _Align.rightBottom => -tp.width,
    };
    final dy = switch (align) {
      _Align.rightMiddle => -tp.height / 2,
      _Align.rightBottom => -tp.height,
      _ => 0.0,
    };
    tp.paint(canvas, at + Offset(dx, dy));
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.points != points ||
      old.total != total ||
      old.reference != reference ||
      old.color != color;
}

enum _Align { leftTop, centerTop, rightTop, rightMiddle, rightBottom }
