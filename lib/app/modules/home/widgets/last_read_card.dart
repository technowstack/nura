import 'package:flutter/material.dart';

import '../../../core/nura_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import 'home_hero_data.dart';

class LastReadCard extends StatelessWidget {
  const LastReadCard({required this.info, required this.onContinue, super.key});

  /// Null when nothing has been read yet.
  final LastReadInfo? info;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final i = info;
    return NuraCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              NuraIcon(NuraIcons.history, color: context.nuraColors.iconAccent),
              const SizedBox(width: NuraSpace.s12),
              Expanded(
                child: i == null
                    ? Text('Belum ada bacaan terakhir', style: text.titleMedium)
                    : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'Terakhir dibaca',
                                  style: text.labelLarge,
                                ),
                              ),
                              const SizedBox(width: NuraSpace.s8),
                              Flexible(
                                child: Text(
                                  i.nameArab,
                                  textDirection: TextDirection.rtl,
                                  style: context.nuraText.arabicTitle.copyWith(
                                    color: context.nuraColors.iconAccent,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          Text(
                            'QS. ${i.nameLatin}: ${i.ayah}',
                            style: text.titleMedium,
                          ),
                        ],
                      ),
              ),
            ],
          ),
          if (i != null) ...[
            const SizedBox(height: NuraSpace.s8),
            Align(
              alignment: Alignment.centerRight,
              child: FilledButton.tonal(
                onPressed: onContinue,
                style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
                child: const Text('Lanjutkan'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
