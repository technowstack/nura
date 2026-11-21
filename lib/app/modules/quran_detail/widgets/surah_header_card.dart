import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/revelation_label.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/surah.dart';
import '../controllers/quran_detail_controller.dart';
import 'bismillah_header.dart';

class SurahHeaderCard extends StatelessWidget {
  const SurahHeaderCard({
    required this.surah,
    required this.basmalah,
    required this.showBismillah,
    this.audio = AyahAudioState.hidden,
    this.onPlaySurah,
    super.key,
  });

  final Surah surah;
  final String basmalah;
  final bool showBismillah;

  /// Audio state for the surah button; hidden removes it.
  final AyahAudioState audio;
  final VoidCallback? onPlaySurah;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final label = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.onHero);
    final value = label?.copyWith(
      color: colors.onHeroAccent,
      fontWeight: FontWeight.w600,
    );
    Widget row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$l  ', style: label),
            TextSpan(text: v, style: value),
          ],
        ),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(NuraSpace.s20),
          decoration: BoxDecoration(
            color: colors.hero,
            borderRadius: BorderRadius.circular(NuraRadius.lg),
          ),
          child: Row(
            children: [
              Expanded(
                flex: 3,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    row('Nama', surah.nameLatin),
                    if (surah.nameId.isNotEmpty) row('Arti', surah.nameId),
                    row('Jumlah ayat', '${surah.ayahCount}'),
                    if (revelationLabel(surah.revelation).isNotEmpty)
                      row('Tempat turun', revelationLabel(surah.revelation)),
                  ],
                ),
              ),
              const SizedBox(width: NuraSpace.s12),
              Flexible(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    surah.nameArab,
                    textDirection: TextDirection.rtl,
                    style: context.nuraText.arabicHero.copyWith(
                      color: colors.onHero,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        if (audio != AyahAudioState.hidden) ...[
          const SizedBox(height: NuraSpace.s12),
          if (audio == AyahAudioState.needsInternet)
            OutlinedButton.icon(
              onPressed: null,
              icon: const NuraIcon(NuraIcons.playArrow),
              label: const Text('Putar surah · Butuh internet'),
            )
          else
            OutlinedButton.icon(
              onPressed: audio == AyahAudioState.loading ? null : onPlaySurah,
              icon: const NuraIcon(NuraIcons.playArrow),
              label: const Text('Putar surah'),
            ),
        ],
        if (showBismillah) ...[
          const SizedBox(height: NuraSpace.s12),
          BismillahHeader(text: basmalah),
        ],
      ],
    );
  }
}
