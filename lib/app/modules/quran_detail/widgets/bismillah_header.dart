import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/nura_card.dart';

class BismillahHeader extends StatelessWidget {
  const BismillahHeader({required this.text, super.key});

  final String text;

  @override
  Widget build(BuildContext context) => NuraCard(
    child: SizedBox(
      width: double.infinity,
      child: Text(
        text,
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
        style: context.nuraText.arabicTitle.copyWith(
          color: context.nuraColors.arabicText,
        ),
      ),
    ),
  );
}
