import 'package:flutter/material.dart';

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
          if (audio != AyahAudioState.hidden) ...[
            const SizedBox(height: NuraSpace.s12),
            if (audio == AyahAudioState.needsInternet)
              OutlinedButton.icon(
                onPressed: null,
                icon: Icon(Icons.play_arrow_rounded),
                label: Text('Putar surah · Butuh internet'),
              )
            else
              OutlinedButton.icon(
                onPressed: audio == AyahAudioState.loading ? null : onPlaySurah,
                icon: const Icon(Icons.play_arrow_rounded),
                label: const Text('Putar surah'),
              ),
          ],
          if (showBismillah) ...[
            const SizedBox(height: NuraSpace.s16),
            BismillahHeader(text: basmalah),
          ],
        ],
      ),
    );
  }
}
