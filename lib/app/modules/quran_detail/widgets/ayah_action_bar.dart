import 'package:flutter/material.dart';

class AyahActionBar extends StatelessWidget {
  const AyahActionBar({
    required this.bookmarked,
    required this.onBookmark,
    required this.onCopy,
    super.key,
  });

  final bool bookmarked;
  final VoidCallback onBookmark;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
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
        onPressed: onCopy,
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        icon: const Icon(Icons.copy, semanticLabel: 'Salin ayat'),
      ),
    ],
  );
}
