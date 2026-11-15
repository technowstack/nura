import 'package:flutter/material.dart';

import '../theme/tokens.dart';

/// Next prayer: name, time, countdown, region and zone, "perkiraan" label.
class NextPrayerCard extends StatelessWidget {
  const NextPrayerCard({
    required this.name,
    required this.time,
    required this.regionLabel,
    required this.zoneLabel,
    this.countdown = '',
    this.estimated = false,
    this.note = '',
    super.key,
  });

  final String name;
  final String time;
  final String regionLabel;
  final String zoneLabel;

  /// Empty hides the countdown.
  final String countdown;
  final bool estimated;

  /// Short extra line (e.g. tomorrow's schedule is missing); empty hides it.
  final String note;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.all(NuraSpace.s16),
      color: scheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(NuraSpace.s16),
        child: Semantics(
          container: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Sholat berikutnya', style: text.labelLarge),
              const SizedBox(height: NuraSpace.s8),
              Text('$name  $time $zoneLabel', style: text.headlineSmall),
              if (countdown.isNotEmpty) ...[
                const SizedBox(height: NuraSpace.s4),
                Text('dalam $countdown', style: text.titleMedium),
              ],
              if (note.isNotEmpty) ...[
                const SizedBox(height: NuraSpace.s4),
                Text(note, style: text.bodyMedium),
              ],
              const SizedBox(height: NuraSpace.s8),
              Text(regionLabel, style: text.bodyMedium),
              if (estimated)
                Text(
                  'perkiraan',
                  style: text.bodyMedium?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
