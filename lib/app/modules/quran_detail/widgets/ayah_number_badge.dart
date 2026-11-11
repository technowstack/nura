import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class AyahNumberBadge extends StatelessWidget {
  const AyahNumberBadge({required this.number, super.key});

  final int number;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: context.nuraColors.ornament,
      shape: BoxShape.circle,
    ),
    child: Text('$number', style: Theme.of(context).textTheme.labelLarge),
  );
}
