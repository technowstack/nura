import 'package:flutter/material.dart';
import 'package:nura/app/core/nura_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../controllers/quran_detail_controller.dart';

/// Equal-width action cells: audio (hidden when unavailable), bookmark,
/// tafsir, copy.
class AyahActionBar extends StatelessWidget {
  const AyahActionBar({
    required this.bookmarked,
    required this.onBookmark,
    required this.onCopy,
    required this.onTafsir,
    this.audio = AyahAudioState.hidden,
    this.onAudio,
    super.key,
  });

  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;
  final VoidCallback onTafsir;
  final AyahAudioState audio;
  final VoidCallback? onAudio;

  Widget _cell(
    BuildContext context, {
    required IconData icon,
    required String label,
    VoidCallback? onPressed,
    String? tooltip,
    bool filled = false,
    Color? color,
  }) {
    final bg = Theme.of(context).colorScheme.surfaceContainerLow;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(NuraRadius.md),
    );
    return IconButton(
      onPressed: onPressed,
      tooltip: tooltip,
      style: IconButton.styleFrom(
        backgroundColor: bg,
        disabledBackgroundColor: bg,
        shape: shape,
        minimumSize: const Size.fromHeight(48),
      ),
      icon: NuraIcon(
        icon,
        filled: filled,
        color: color ?? context.nuraColors.iconAccent,
        semanticLabel: label,
      ),
    );
  }

  Widget? _audioCell(BuildContext context) => switch (audio) {
    AyahAudioState.hidden => null,
    AyahAudioState.loading => DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(NuraRadius.md),
      ),
      child: const Center(
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
    AyahAudioState.needsInternet => _cell(
      context,
      icon: NuraIcons.playArrow,
      label: 'Butuh internet',
      tooltip: 'Butuh internet',
    ),
    AyahAudioState.playing => _cell(
      context,
      icon: NuraIcons.pause,
      label: 'Jeda',
      tooltip: 'Jeda',
      onPressed: onAudio,
    ),
    AyahAudioState.ready || AyahAudioState.paused => _cell(
      context,
      icon: NuraIcons.playArrow,
      label: 'Putar ayat',
      tooltip: 'Putar ayat',
      onPressed: onAudio,
    ),
  };

  @override
  Widget build(BuildContext context) {
    final cells = <Widget>[
      ?_audioCell(context),
      _cell(
        context,
        icon: NuraIcons.bookmark,
        label: bookmarked ? 'Hapus bookmark' : 'Tambah bookmark',
        onPressed: onBookmark,
        filled: bookmarked,
        color: bookmarked ? Theme.of(context).colorScheme.primary : null,
      ),
      _cell(
        context,
        icon: NuraIcons.menuBook,
        label: 'Lihat tafsir',
        onPressed: onTafsir,
      ),
      _cell(
        context,
        icon: NuraIcons.contentCopy,
        label: 'Salin ayat',
        onPressed: onCopy,
      ),
    ];
    return SizedBox(
      height: 48,
      child: Row(
        children: [
          for (var i = 0; i < cells.length; i++) ...[
            if (i > 0) const SizedBox(width: NuraSpace.s8),
            Expanded(child: cells[i]),
          ],
        ],
      ),
    );
  }
}
