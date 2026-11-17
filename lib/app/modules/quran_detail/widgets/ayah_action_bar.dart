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
        icon: Icon(Icons.play_arrow_rounded, semanticLabel: 'Butuh internet'),
      ),
      AyahAudioState.playing => IconButton(
        onPressed: onAudio,
        tooltip: 'Jeda',
        constraints: box,
        icon: const Icon(Icons.pause_rounded, semanticLabel: 'Jeda'),
      ),
      AyahAudioState.ready || AyahAudioState.paused => IconButton(
        onPressed: onAudio,
        tooltip: 'Putar ayat',
        constraints: box,
        icon: const Icon(Icons.play_arrow_rounded, semanticLabel: 'Putar ayat'),
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
      icon: const Icon(Icons.playlist_play, semanticLabel: 'Putar dari sini'),
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
        icon: Icon(
          bookmarked ? Icons.bookmark : Icons.bookmark_border,
          color: bookmarked ? Theme.of(context).colorScheme.primary : null,
          semanticLabel: bookmarked ? 'Hapus bookmark' : 'Tambah bookmark',
        ),
      ),
      IconButton(
        onPressed: onTafsir,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.menu_book, semanticLabel: 'Lihat tafsir'),
      ),
      IconButton(
        onPressed: onCopy,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.copy, semanticLabel: 'Salin ayat'),
      ),
    ],
  );
}
