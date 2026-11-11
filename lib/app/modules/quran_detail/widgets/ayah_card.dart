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

  final bool lastRead;
  final ReadingPrefs prefs;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onTafsir;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lastRead)
          Padding(
            padding: const EdgeInsets.only(bottom: NuraSpace.s8),
            child: Row(
              children: [
                const Icon(Icons.history_rounded, size: 16),
                const SizedBox(width: NuraSpace.s4),
                Flexible(
                  child: Text(
                    'Terakhir dibaca',
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
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
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NuraSpace.s20,
        0,
        NuraSpace.s20,
        NuraSpace.s12,
      ),
      child: lastRead
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: colors.lastReadHighlight,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(NuraSpace.s12),
                child: card,
              ),
            )
          : card,
    );
  }
}
