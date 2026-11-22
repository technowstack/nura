import 'package:flutter/material.dart';
import 'package:nura/app/core/nura_icons.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import '../../../core/widgets/ornament_badge.dart';
import '../controllers/hadith_list_controller.dart';

/// Hadith card: number badge, book name, matan preview, bookmark slot.
class HadithListTile extends StatelessWidget {
  const HadithListTile({required this.item, required this.onTap, super.key});

  final HadithListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
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
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OrnamentBadge(label: '${item.ref.number}'),
            const SizedBox(width: NuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.bookName,
                    style: text.labelMedium?.copyWith(
                      color: context.nuraColors.iconAccent,
                    ),
                  ),
                  const SizedBox(height: NuraSpace.s4),
                  Text(
                    item.preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: text.bodyMedium?.copyWith(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            const SizedBox(width: NuraSpace.s8),
            // Slot reserved on every card so text widths stay equal.
            SizedBox(
              width: 32,
              child: item.bookmarked
                  ? NuraIcon(
                      NuraIcons.bookmark,
                      filled: true,
                      color: scheme.primary,
                      semanticLabel: 'Ditandai',
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
