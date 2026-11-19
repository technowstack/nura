import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../controllers/hadith_list_controller.dart';

/// Temporary tile (hadith screens are not designed yet).
class HadithListTile extends StatelessWidget {
  const HadithListTile({required this.item, required this.onTap, super.key});

  final HadithListItem item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
      title: Text(item.numberLabel, style: text.titleMedium),
      subtitle: Text(
        item.preview,
        style: text.bodyMedium,
        maxLines: 3,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: item.bookmarked
          ? const NuraIcon(NuraIcons.bookmark, semanticLabel: 'Ditandai')
          : null,
    );
  }
}
