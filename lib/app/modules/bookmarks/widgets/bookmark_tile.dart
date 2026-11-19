import 'package:flutter/material.dart';

import '../../../core/nura_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import '../controllers/bookmark_item.dart';

class BookmarkTile extends StatelessWidget {
  const BookmarkTile({required this.item, required this.onTap, super.key});

  final BookmarkItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NuraSpace.s16,
        vertical: NuraSpace.s4,
      ),
      child: NuraCard(
        onTap: onTap,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.title, style: text.titleMedium),
                  Text(
                    item.body,
                    style: text.bodyMedium,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: NuraSpace.s8),
            // Decorative: every bookmark in this list is bookmarked.
            ExcludeSemantics(
              child: NuraIcon(
                NuraIcons.bookmark,
                filled: true,
                color: context.nuraColors.iconAccent,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
