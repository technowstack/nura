import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/nura_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Full-bleed green header with the pointed niche of the app logo. The star
/// marks the welcome step; later steps show [icon] inside the same niche.
class OnboardingHeader extends StatelessWidget {
  const OnboardingHeader({required this.height, this.icon, super.key});

  /// Height below the status bar.
  final double height;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final top = MediaQuery.paddingOf(context).top;
    final nicheWidth = height * 0.62;
    return ExcludeSemantics(
      child: Container(
        height: height + top,
        padding: EdgeInsets.only(top: top + NuraSpace.s16),
        decoration: BoxDecoration(
          color: colors.hero,
          borderRadius: const BorderRadius.vertical(
            bottom: Radius.circular(NuraRadius.xl),
          ),
        ),
        alignment: Alignment.bottomCenter,
        child: SizedBox(
          width: nicheWidth,
          child: CustomPaint(
            painter: _NichePainter(
              frame: colors.onHero,
              niche: colors.heroShape,
              depth: colors.hero,
              star: icon == null ? colors.onHeroAccent : null,
            ),
            child: icon == null
                ? const SizedBox.expand()
                : SizedBox.expand(
                    child: Align(
                      alignment: const Alignment(0, 0.45),
                      child: NuraIcon(
                        icon ?? NuraIcons.home,
                        size: nicheWidth * 0.36,
                        color: colors.onHeroAccent,
                      ),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

class _NichePainter extends CustomPainter {
  const _NichePainter({
    required this.frame,
    required this.niche,
    required this.depth,
    required this.star,
  });

  final Color frame;
  final Color niche;
  final Color depth;
  final Color? star;

  /// Pointed arch standing on the bottom edge, inset from the sides and top.
  Path _arch(Size s, double side, double top) {
    final w = s.width, h = s.height;
    final spring = top + (h - top) * 0.45;
    return Path()
      ..moveTo(side, h)
      ..lineTo(side, spring)
      ..quadraticBezierTo(side, top + (spring - top) * 0.35, w / 2, top)
      ..quadraticBezierTo(
        w - side,
        top + (spring - top) * 0.35,
        w - side,
        spring,
      )
      ..lineTo(w - side, h)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    canvas
      ..drawPath(_arch(size, 0, 0), Paint()..color = frame)
      ..drawPath(_arch(size, w * 0.13, h * 0.13), Paint()..color = niche)
      ..drawPath(_arch(size, w * 0.24, h * 0.30), Paint()..color = depth);
    final color = star;
    if (color == null) return;
    // Eight points: a square and the same square turned 45 degrees.
    final paint = Paint()..color = color;
    final half = w * 0.14;
    canvas
      ..save()
      ..translate(w / 2, h * 0.68);
    for (var i = 0; i < 2; i++) {
      canvas
        ..drawRect(Rect.fromCircle(center: Offset.zero, radius: half), paint)
        ..rotate(math.pi / 4);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_NichePainter old) =>
      old.frame != frame || old.niche != niche || old.star != star;
}
