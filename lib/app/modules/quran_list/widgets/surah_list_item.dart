import 'package:flutter/material.dart';

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

  static String revelationLabel(String revelation) => switch (revelation) {
    'makkiyah' => 'Makkiyah',
    'madaniyah' => 'Madaniyah',
    _ => '',
  };

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final revelation = revelationLabel(surah.revelation);
    return Material(
      color: state == SurahItemState.lastRead
          ? context.nuraColors.lastReadHighlight
          : Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: NuraSpace.s16,
              vertical: NuraSpace.s12,
            ),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: context.nuraColors.ornament,
                    shape: BoxShape.circle,
                  ),
                  child: Text('${surah.number}', style: text.labelLarge),
                ),
                const SizedBox(width: NuraSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(surah.nameLatin, style: text.titleMedium),
                      Text(surah.nameId, style: text.bodyMedium),
                      Wrap(
                        spacing: NuraSpace.s8,
                        children: [
                          Text(
                            '${surah.ayahCount} ayat',
                            style: text.bodySmall,
                          ),
                          if (revelation.isNotEmpty)
                            Text(revelation, style: text.bodySmall),
                          if (state == SurahItemState.lastRead) ...[
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.history, size: 16),
                                Flexible(
                                  child: Text(
                                    'Terakhir dibaca',
                                    style: text.labelMedium,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                if (state == SurahItemState.bookmarked)
                  const Padding(
                    padding: EdgeInsets.only(left: NuraSpace.s8),
                    child: Icon(
                      Icons.bookmark,
                      semanticLabel: 'Ditandai bookmark',
                    ),
                  ),
                const SizedBox(width: NuraSpace.s8),
                Flexible(
                  child: Text(
                    surah.nameArab,
                    style: context.nuraText.arabicTitle.copyWith(
                      color: context.nuraColors.arabicText,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
