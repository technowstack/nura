import 'package:flutter/material.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/content_pipeline/content_schema.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import '../controllers/hadith_books_controller.dart';

/// Book card: icon, Latin name and count, Arabic name, chevron.
class HadithBookTile extends StatelessWidget {
  const HadithBookTile({required this.item, required this.onTap, super.key});

  final HadithBookItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final accent = context.nuraColors.iconAccent;
    final arab = hadithBookNameArab(item.book.slug);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        NuraSpace.s16,
        0,
        NuraSpace.s16,
        NuraSpace.s8,
      ),
      child: NuraCard(
        onTap: onTap,
        child: Row(
          children: [
            NuraIcon(NuraIcons.menuBook, size: 24, color: accent),
            const SizedBox(width: NuraSpace.s16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item.book.name, style: text.titleMedium),
                  Text(
                    item.countLabel,
                    style: text.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (arab != null)
              Flexible(
                child: Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: NuraSpace.s8,
                  ),
                  child: Text(
                    arab,
                    textDirection: TextDirection.rtl,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.nuraText.arabicTitle.copyWith(color: accent),
                  ),
                ),
              ),
            const SizedBox(width: NuraSpace.s8),
            const NuraIcon(NuraIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}
