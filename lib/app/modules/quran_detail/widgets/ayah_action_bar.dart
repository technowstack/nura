import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import '../controllers/quran_detail_controller.dart';

class AyahActionBar extends StatelessWidget {
  const AyahActionBar({
    required this.bookmarked,
    required this.onBookmark,
    required this.onCopy,
    required this.onTafsir,
    this.audio = AyahAudioState.hidden,
    this.onAudio,
    this.onPlayFromHere,
    super.key,
  });

  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onTafsir;
  final AyahAudioState audio;
  final VoidCallback? onAudio;
  final VoidCallback? onPlayFromHere;

  Widget _audioButton() {
    const box = BoxConstraints(minWidth: 48, minHeight: 48);
    return switch (audio) {
      AyahAudioState.hidden => const SizedBox.shrink(),
      AyahAudioState.loading => const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              semanticsLabel: 'Memuat audio',
            ),
          ),
        ),
      ),
      AyahAudioState.needsInternet => const IconButton(
        onPressed: null,
        tooltip: 'Butuh internet',
        constraints: box,
        icon: NuraIcon(NuraIcons.playArrow, semanticLabel: 'Butuh internet'),
      ),
      AyahAudioState.playing => IconButton(
        onPressed: onAudio,
        tooltip: 'Jeda',
        constraints: box,
        icon: const NuraIcon(NuraIcons.pause, semanticLabel: 'Jeda'),
      ),
      AyahAudioState.ready || AyahAudioState.paused => IconButton(
        onPressed: onAudio,
        tooltip: 'Putar ayat',
        constraints: box,
        icon: const NuraIcon(NuraIcons.playArrow, semanticLabel: 'Putar ayat'),
      ),
    };
  }

  Widget _fromHereButton() {
    final off =
        audio == AyahAudioState.needsInternet ||
        audio == AyahAudioState.loading;
    return IconButton(
      onPressed: off ? null : onPlayFromHere,
      tooltip: audio == AyahAudioState.needsInternet
          ? 'Butuh internet'
          : 'Putar dari sini',
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      icon: const NuraIcon(
        NuraIcons.playlistPlay,
        semanticLabel: 'Putar dari sini',
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      if (audio != AyahAudioState.hidden) ...[
        _audioButton(),
        _fromHereButton(),
      ],
      IconButton(
        onPressed: onBookmark,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: NuraIcon(
          NuraIcons.bookmark,
          filled: bookmarked,
          color: bookmarked ? Theme.of(context).colorScheme.primary : null,
          semanticLabel: bookmarked ? 'Hapus bookmark' : 'Tambah bookmark',
        ),
      ),
      IconButton(
        onPressed: onTafsir,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const NuraIcon(NuraIcons.menuBook, semanticLabel: 'Lihat tafsir'),
      ),
      IconButton(
        onPressed: onCopy,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const NuraIcon(
          NuraIcons.contentCopy,
          semanticLabel: 'Salin ayat',
        ),
      ),
    ],
  );
}
