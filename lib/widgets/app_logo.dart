import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../theme.dart';

/// The TripMate mark (same design as the launcher icon), drawn in code so
/// no image asset is bundled.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 96});
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox.square(
        dimension: size,
        child: CustomPaint(painter: _LogoPainter()),
      );
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size s) {
    final w = s.width;
    final rect = Offset.zero & s;
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect, Radius.circular(w * 0.24)),
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2A9097), AppColors.primaryDark],
        ).createShader(rect),
    );
    final c = Offset(w / 2, w * 0.56);
    final r = w * 0.30;
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r),
      math.pi * 0.75,
      math.pi * 1.5,
      false,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = w * 0.075
        ..strokeCap = StrokeCap.round,
    );
    const a = -math.pi * 0.25; // needle pointing up-right
    canvas.drawLine(
      c,
      c + Offset(math.cos(a), math.sin(a)) * r * 0.78,
      Paint()
        ..color = AppColors.accent
        ..strokeWidth = w * 0.07
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawCircle(c, w * 0.065, Paint()..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
