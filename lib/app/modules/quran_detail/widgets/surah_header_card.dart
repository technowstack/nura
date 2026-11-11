import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/surah.dart';
import 'bismillah_header.dart';

class SurahHeaderCard extends StatelessWidget {
  const SurahHeaderCard({
    required this.surah,
    required this.basmalah,
    required this.showBismillah,
    super.key,
  });

  final Surah surah;
  final String basmalah;
  final bool showBismillah;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(NuraSpace.s20),
      decoration: BoxDecoration(
        color: context.nuraColors.ornament,
        borderRadius: BorderRadius.circular(NuraRadius.lg),
      ),
      child: Column(
        children: [
          Text(
            surah.nameArab,
            textDirection: TextDirection.rtl,
            style: context.nuraText.arabicTitle.copyWith(
              color: context.nuraColors.arabicText,
            ),
          ),
          Text(
            surah.nameLatin,
            style: text.titleMedium,
            textAlign: TextAlign.center,
          ),
          Text(
            surah.nameId,
            style: text.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (showBismillah) ...[
            const SizedBox(height: NuraSpace.s16),
            BismillahHeader(text: basmalah),
          ],
        ],
      ),
    );
  }
}
