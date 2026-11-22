import 'package:flutter/material.dart';

import '../theme/tokens.dart';

class NuraCard extends StatelessWidget {
  const NuraCard({
    required this.child,
    this.color,
    this.padding = const EdgeInsets.all(NuraSpace.s16),
    this.onTap,
    super.key,
  });

  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(NuraRadius.lg);
    final padded = Padding(padding: padding, child: child);
    return Material(
      color: color ?? scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
      child: onTap == null
          ? padded
          : InkWell(
              onTap: onTap,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: NuraSpace.s48),
                child: padded,
              ),
            ),
    );
  }
}
