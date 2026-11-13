import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/juz.dart';

class JuzListItem extends StatelessWidget {
  const JuzListItem({required this.juz, required this.onTap, super.key});

  final Juz juz;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return ListTile(
      onTap: onTap,
      minTileHeight: 56,
      contentPadding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
      title: Text('Juz ${juz.number}', style: text.titleMedium),
      subtitle: Text(
        '${juz.startSurah}:${juz.startAyah} – ${juz.endSurah}:${juz.endAyah}',
        style: text.bodyMedium,
      ),
    );
  }
}
