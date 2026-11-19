import 'package:flutter/material.dart';

/// Flat one-tone dome and minaret skyline; no gradient.
class HeroSilhouettePainter extends CustomPainter {
  const HeroSilhouettePainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color;
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Rect.fromLTWH(w * 0.02, h * 0.15, w * 0.06, h * 0.85), p);
    canvas.drawRect(Rect.fromLTWH(w * 0.92, h * 0.15, w * 0.06, h * 0.85), p);
    for (final (cx, r) in [(0.18, 0.09), (0.5, 0.17), (0.82, 0.09)]) {
      canvas.drawArc(
        Rect.fromCircle(center: Offset(w * cx, h), radius: w * r),
        3.14159,
        3.14159,
        true,
        p,
      );
    }
  }

  @override
  bool shouldRepaint(HeroSilhouettePainter old) => old.color != color;
}
