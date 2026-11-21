import 'package:flutter/material.dart';
import 'package:nura/app/core/nura_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';

/// Equal-width action cells: copy and bookmark.
class HadithActionBar extends StatelessWidget {
  const HadithActionBar({
    required this.bookmarked,
    required this.onBookmark,
    required this.onCopy,
    super.key,
  });

  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;

  Widget _cell(
    BuildContext context, {
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
    bool filled = false,
    Color? color,
  }) {
    final bg = Theme.of(context).colorScheme.surfaceContainerLow;
    return IconButton(
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: bg,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(NuraRadius.md),
        ),
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

  @override
  Widget build(BuildContext context) => SizedBox(
    height: 48,
    child: Row(
      children: [
        Expanded(
          child: _cell(
            context,
            icon: NuraIcons.contentCopy,
            label: 'Salin hadis',
            onPressed: onCopy,
          ),
        ),
        const SizedBox(width: NuraSpace.s8),
        Expanded(
          child: _cell(
            context,
            icon: NuraIcons.bookmark,
            label: bookmarked ? 'Hapus bookmark' : 'Tambah bookmark',
            onPressed: onBookmark,
            filled: bookmarked,
            color: bookmarked ? Theme.of(context).colorScheme.primary : null,
          ),
        ),
      ],
    ),
  );
}
