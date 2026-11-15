import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/hadith_books_controller.dart';

/// Temporary tile (hadith screens are not designed yet).
class HadithBookTile extends StatelessWidget {
  const HadithBookTile({required this.item, required this.onTap, super.key});

  final HadithBookItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
      title: Text(item.book.name, style: text.titleMedium),
      subtitle: Text(item.countLabel, style: text.bodyMedium),
      trailing: const Icon(Icons.chevron_right),
    );
  }
}
