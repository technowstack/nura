import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/reading_prefs.dart';
import '../controllers/hadith_detail_controller.dart';

/// Arabic text, optional translation and truncation note. No maxLines or
/// ellipsis: the full text must be readable by scrolling.
class HadithTextCard extends StatelessWidget {
  const HadithTextCard({required this.content, required this.prefs, super.key});

  final HadithDetailContent content;
  final ReadingPrefs prefs;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        content.arab,
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
        style: context.nuraText.arabicReading.copyWith(
          fontSize: prefs.arabicFontSize,
          color: context.nuraColors.arabicText,
        ),
      ),
      if (prefs.showTranslation) ...[
        const SizedBox(height: NuraSpace.s16),
        Text(content.translation, style: context.nuraText.translation),
      ],
      if (content.showTruncationNote) ...[
        const SizedBox(height: NuraSpace.s16),
        Text(
          'Teks hadis ini terpotong di sumber data.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ],
  );
}
