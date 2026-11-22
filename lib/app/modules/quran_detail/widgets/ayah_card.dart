import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/ayah_end_marker.dart';
import '../../../core/widgets/nura_card.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/reading_prefs.dart';
import '../controllers/quran_detail_controller.dart';
import 'ayah_action_bar.dart';

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

  Widget? _menu() {
    if (audio == AyahAudioState.hidden) return null;
    final off =
        audio == AyahAudioState.needsInternet ||
        audio == AyahAudioState.loading;
    return PopupMenuButton<void>(
      tooltip: 'Menu ayat',
      style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
      icon: const NuraIcon(NuraIcons.moreHoriz),
      itemBuilder: (_) => [
        PopupMenuItem<void>(
          enabled: !off,
          onTap: onPlayFromHere,
          child: Text(
            audio == AyahAudioState.needsInternet
                ? 'Putar dari sini · Butuh internet'
                : 'Putar dari sini',
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final scheme = Theme.of(context).colorScheme;
    final menu = _menu();
    final arabic = context.nuraText.arabicReading.copyWith(
      fontSize: prefs.arabicFontSize,
      color: colors.arabicText,
    );
    final card = NuraCard(
      color: playing
          ? scheme.primaryContainer
          : lastRead
          ? colors.lastReadHighlight
          : null,
      child: Column(
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
          SizedBox(
            height: 48,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  '${ayah.ayahNumber}',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: colors.iconAccent),
                ),
                ?menu,
              ],
            ),
          ),
          Text.rich(
            TextSpan(
              children: ayahTextSpans(
                ayah.arab,
                ayah.ayahNumber,
                style: arabic,
              ),
            ),
            textAlign: TextAlign.right,
            textDirection: TextDirection.rtl,
            style: arabic,
          ),
          if (prefs.showTranslation) ...[
            const SizedBox(height: NuraSpace.s12),
            Text(ayah.translation, style: context.nuraText.translation),
          ],
          const SizedBox(height: NuraSpace.s12),
          Divider(height: 1, color: scheme.outlineVariant),
          const SizedBox(height: NuraSpace.s12),
          AyahActionBar(
            bookmarked: bookmarked,
            onBookmark: onBookmark,
            onCopy: onCopy,
            onTafsir: onTafsir,
            audio: audio,
            onAudio: onAudio,
          ),
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NuraSpace.s20,
        0,
        NuraSpace.s20,
        NuraSpace.s12,
      ),
      child: playing
          ? Container(
              foregroundDecoration: BoxDecoration(
                border: Border.all(color: scheme.primary),
                borderRadius: BorderRadius.circular(NuraRadius.lg),
              ),
              child: card,
            )
          : card,
    );
  }
}
