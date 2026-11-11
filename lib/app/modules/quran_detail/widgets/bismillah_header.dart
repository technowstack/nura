import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';

class BismillahHeader extends StatelessWidget {
  const BismillahHeader({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    textDirection: TextDirection.rtl,
    style: context.nuraText.arabicTitle.copyWith(
      color: context.nuraColors.arabicText,
    ),
  );
}
