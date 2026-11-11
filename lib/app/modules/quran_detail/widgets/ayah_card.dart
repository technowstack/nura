import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/reading_prefs.dart';
import 'ayah_action_bar.dart';
import 'ayah_number_badge.dart';

class AyahCard extends StatelessWidget {
  const AyahCard({
    required this.ayah,
    required this.bookmarked,
    required this.lastRead,
    required this.prefs,
    required this.onBookmark,
    required this.onCopy,
    required this.onTafsir,
    super.key,
  });

  final Ayah ayah;
  final bool bookmarked;

  /// Reserved: the last-read highlight is added in a later task.
  final bool lastRead;
  final ReadingPrefs prefs;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onTafsir;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      NuraSpace.s20,
      0,
      NuraSpace.s20,
      NuraSpace.s12,
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            AyahNumberBadge(number: ayah.ayahNumber),
            AyahActionBar(
              bookmarked: bookmarked,
              onBookmark: onBookmark,
              onCopy: onCopy,
              onTafsir: onTafsir,
            ),
          ],
        ),
        Text(
          ayah.arab,
          textAlign: TextAlign.right,
          textDirection: TextDirection.rtl,
          style: context.nuraText.arabicReading.copyWith(
            fontSize: prefs.arabicFontSize,
            color: context.nuraColors.arabicText,
          ),
        ),
        if (prefs.showTranslation) ...[
          const SizedBox(height: NuraSpace.s8),
          Text(ayah.translation, style: context.nuraText.translation),
        ],
      ],
    ),
  );
}
