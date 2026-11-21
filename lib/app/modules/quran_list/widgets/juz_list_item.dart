import 'package:flutter/material.dart';

import '../../../core/nura_icons.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import '../../../core/widgets/ornament_badge.dart';
import '../../../data/models/juz.dart';

class JuzListItem extends StatelessWidget {
  const JuzListItem({
    required this.juz,
    required this.range,
    required this.onTap,
    super.key,
  });

  final Juz juz;

  /// Display text such as 'Al-Fatihah 1 – Al-Baqarah 141'.
  final String range;
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
          children: [
            OrnamentBadge(label: '${juz.number}'),
            const SizedBox(width: NuraSpace.s12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Juz ${juz.number}', style: text.titleMedium),
                  Text(range, style: text.bodyMedium),
                ],
              ),
            ),
            const NuraIcon(NuraIcons.chevronRight),
          ],
        ),
      ),
    );
  }
}
