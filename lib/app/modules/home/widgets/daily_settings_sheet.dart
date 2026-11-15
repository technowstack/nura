import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/daily_content.dart';
import '../controllers/home_controller.dart';

Future<void> showDailySettingsSheet(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const DailySettingsSheet(),
    );

class DailySettingsSheet extends GetView<HomeController> {
  const DailySettingsSheet({super.key});

  static const _options = [
    (HadithSource.defaultBm, 'Bukhari dan Muslim'),
    (HadithSource.allBooks, 'Sembilan kitab'),
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          NuraSpace.s16,
          0,
          NuraSpace.s16,
          NuraSpace.s16,
        ),
        child: Obx(() {
          final current = controller.hadithSource.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Pengaturan harian', style: text.titleMedium),
              const SizedBox(height: NuraSpace.s8),
              Text('Sumber hadis', style: text.labelLarge),
              for (final (source, label) in _options)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  minTileHeight: 48,
                  selected: source == current,
                  title: Text(label),
                  trailing: source == current ? const Icon(Icons.check) : null,
                  onTap: () => controller.setHadithSource(source),
                ),
              if (current == HadithSource.allBooks)
                Text(
                  'Kitab selain Bukhari dan Muslim memuat hadis dengan '
                  'derajat yang beragam.',
                  style: text.bodySmall,
                ),
              // Notification switch and time are added with the reminder.
            ],
          );
        }),
      ),
    );
  }
}
