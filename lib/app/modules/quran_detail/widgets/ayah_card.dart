import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/reading_prefs.dart';
import '../controllers/quran_detail_controller.dart';
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
    this.audio = AyahAudioState.hidden,
    this.playing = false,
    this.onAudio,
    this.onPlayFromHere,
    super.key,
  });

  final Ayah ayah;
  final bool bookmarked;

  final bool lastRead;
  final ReadingPrefs prefs;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onTafsir;
  final AyahAudioState audio;

  /// True for the ayah currently playing (or paused) in this surah.
  final bool playing;
  final VoidCallback? onAudio;
  final VoidCallback? onPlayFromHere;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final card = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (lastRead)
          Padding(
            padding: const EdgeInsets.only(bottom: NuraSpace.s8),
            child: SizedBox(
              height: 24,
              child: Row(
                children: [
                  const NuraIcon(NuraIcons.history, size: 16),
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
              audio: audio,
              onAudio: onAudio,
              onPlayFromHere: onPlayFromHere,
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
      child: lastRead || playing
          ? DecoratedBox(
              decoration: BoxDecoration(
                color: playing
                    ? Theme.of(context).colorScheme.primaryContainer
                    : colors.lastReadHighlight,
                border: playing
                    ? Border.all(color: Theme.of(context).colorScheme.primary)
                    : null,
                borderRadius: BorderRadius.circular(NuraRadius.md),
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
