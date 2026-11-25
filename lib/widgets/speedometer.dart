import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// Speedometer dial with a needle and a large numeric readout.
class Speedometer extends StatelessWidget {
  const Speedometer({super.key, required this.speedKmh, this.maxKmh = 200});

  final double speedKmh;
  final double maxKmh;

  @override
  Widget build(BuildContext context) {
    // Grow the scale if the car goes faster than the dial.
    final scale = speedKmh > maxKmh ? (speedKmh / 40).ceil() * 40.0 : maxKmh;
    return AspectRatio(
      aspectRatio: 1.15,
      child: TweenAnimationBuilder<double>(
        tween: Tween(end: speedKmh.clamp(0, scale)),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (context, value, _) => Semantics(
          label: 'Speed ${speedKmh.round()} kilometres per hour',
          child: CustomPaint(
            painter: _DialPainter(value: value, max: scale),
            child: Align(
              alignment: const Alignment(0, 0.62),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    speedKmh.round().toString(),
                    style: const TextStyle(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: AppColors.text,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                  const Text('km/h',
                      style: TextStyle(fontSize: 14, color: AppColors.muted)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DialPainter extends CustomPainter {
  _DialPainter({required this.value, required this.max});

  final double value;
  final double max;

  static const double _start = math.pi * 0.75; // 135°
  static const double _sweep = math.pi * 1.5; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final c = Offset(size.width / 2, size.height * 0.52);
    final r = math.min(size.width, size.height) * 0.44;
    const stroke = 14.0;
    final rect = Rect.fromCircle(center: c, radius: r);

    // Track and progress arcs.
    canvas.drawArc(
        rect,
        _start,
        _sweep,
        false,
        Paint()
          ..color = const Color(0xFFE2EBEA)
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.round);
    final frac = (value / max).clamp(0.0, 1.0);
    if (frac > 0) {
      canvas.drawArc(
          rect,
          _start,
          _sweep * frac,
          false,
          Paint()
            ..shader = const SweepGradient(
              // Offset slightly so the round start cap stays teal.
              startAngle: 0,
              endAngle: _sweep + 0.2,
              colors: [AppColors.primary, AppColors.accent],
              transform: GradientRotation(_start - 0.1),
            ).createShader(rect)
            ..style = PaintingStyle.stroke
            ..strokeWidth = stroke
            ..strokeCap = StrokeCap.round);
    }

    // Ticks and labels.
    final tick = Paint()
      ..color = AppColors.muted
      ..strokeCap = StrokeCap.round;
    final step = max / 20; // 20 minor divisions
    for (var i = 0; i <= 20; i++) {
      final a = _start + _sweep * i / 20;
      final major = i % 2 == 0;
      final inner = r - stroke - (major ? 12 : 6);
      final outer = r - stroke - 2;
      tick.strokeWidth = major ? 2.2 : 1.2;
      canvas.drawLine(c + _polar(a, inner), c + _polar(a, outer), tick);
      if (major && i % 4 == 0) {
        final tp = TextPainter(
          text: TextSpan(
            text: (step * i).round().toString(),
            style: const TextStyle(fontSize: 11, color: AppColors.muted),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        final pos = c + _polar(a, inner - 14);
        tp.paint(canvas, pos - Offset(tp.width / 2, tp.height / 2));
      }
    }

    // Needle.
    final na = _start + _sweep * frac;
    final needle = Paint()
      ..color = AppColors.text
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(c - _polar(na, 12), c + _polar(na, r - stroke - 18), needle);
    canvas.drawCircle(c, 9, Paint()..color = AppColors.text);
    canvas.drawCircle(c, 4, Paint()..color = AppColors.accent);
  }

  Offset _polar(double a, double len) =>
      Offset(math.cos(a) * len, math.sin(a) * len);

  @override
  bool shouldRepaint(_DialPainter old) => old.value != value || old.max != max;
}
