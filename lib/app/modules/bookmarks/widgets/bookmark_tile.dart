import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/bookmark_item.dart';

class BookmarkTile extends StatelessWidget {
  const BookmarkTile({required this.item, required this.onTap, super.key});

  final BookmarkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 72),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: NuraSpace.s16,
            vertical: NuraSpace.s12,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${item.surah.nameLatin} · ayat ${item.ayah.ayahNumber}',
                style: text.titleMedium,
              ),
              Text(
                item.ayah.translation,
                style: text.bodyMedium,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
