import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/core/widgets/ornament_badge.dart';
import 'package:flutter/material.dart';

import '../../../core/revelation_label.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../data/models/surah.dart';

enum SurahItemState { normal, bookmarked, lastRead }

class SurahListItem extends StatelessWidget {
  const SurahListItem({
    required this.surah,
    required this.state,
    required this.onTap,
    super.key,
  });

  final Surah surah;
  final SurahItemState state;
  final VoidCallback onTap;

  /// A separator dot kept with the item after it: it never starts a wrapped
  /// line and screen readers skip it.
  Widget _dotted(Text item) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      ExcludeSemantics(child: Text('·', style: item.style)),
      const SizedBox(width: NuraSpace.s4),
      Flexible(child: item),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final revelation = revelationLabel(surah.revelation);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: NuraSpace.s16,
        vertical: NuraSpace.s4,
      ),
      child: NuraCard(
        color: state == SurahItemState.lastRead
            ? context.nuraColors.lastReadHighlight
            : null,
        onTap: onTap,
        child: Row(
          children: [
            OrnamentBadge(label: '${surah.number}'),
            const SizedBox(width: NuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(surah.nameLatin, style: text.titleMedium),
                  Wrap(
                    spacing: NuraSpace.s4,
                    runSpacing: NuraSpace.s4,
                    children: [
                      Text(surah.nameId, style: text.bodyMedium),
                      _dotted(
                        Text('${surah.ayahCount} ayat', style: text.bodyMedium),
                      ),
                      if (revelation.isNotEmpty)
                        _dotted(Text(revelation, style: text.bodyMedium)),
                      if (state == SurahItemState.lastRead)
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const NuraIcon(NuraIcons.history, size: 16),
                            Flexible(
                              child: Text(
                                'Terakhir dibaca',
                                style: text.labelMedium,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (state == SurahItemState.bookmarked)
              const Padding(
                padding: EdgeInsets.only(left: NuraSpace.s8),
                child: NuraIcon(
                  NuraIcons.bookmark,
                  filled: true,
                  semanticLabel: 'Ditandai bookmark',
                ),
              ),
            const SizedBox(width: NuraSpace.s8),
            Flexible(
              child: Text(
                surah.nameArab,
                style: context.nuraText.arabicTitle.copyWith(
                  color: context.nuraColors.iconAccent,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
