import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';

/// One time of the day; the next prayer is highlighted.
class PrayerTimeRow extends StatelessWidget {
  const PrayerTimeRow({
    required this.label,
    required this.time,
    required this.highlighted,
    super.key,
  });

  final String label;
  final String time;
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final style = highlighted
        ? text.titleMedium?.copyWith(fontWeight: FontWeight.bold)
        : text.bodyLarge;
    return ListTile(
      minTileHeight: 48,
      selected: highlighted,
      contentPadding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
      title: Text(label, style: style),
      trailing: Text(time, style: style),
    );
  }
}
