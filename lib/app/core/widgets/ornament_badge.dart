import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../theme/tokens.dart';

/// Eight-pointed star outline (two squares rotated 45 degrees) with a label.
class OrnamentBadge extends StatelessWidget {
  const OrnamentBadge({
    required this.label,
    this.size = NuraSpace.s36,
    super.key,
  });

  final String label;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        ExcludeSemantics(
          child: CustomPaint(
            size: Size.square(size),
            painter: _StarPainter(context.nuraColors.iconAccent),
          ),
        ),
        Text(label, style: Theme.of(context).textTheme.labelLarge),
      ],
    ),
  );
}

class _StarPainter extends CustomPainter {
  const _StarPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Inset so the stroke and the diagonal square corners stay inside bounds.
    final half = size.width / 2 - 1;
    final side = half * math.sqrt2;
    canvas.translate(size.width / 2, size.height / 2);
    for (final angle in [0.0, math.pi / 4]) {
      canvas.save();
      canvas.rotate(angle);
      canvas.drawRect(
        Rect.fromCenter(center: Offset.zero, width: side, height: side),
        paint,
      );
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_StarPainter old) => old.color != color;
}
