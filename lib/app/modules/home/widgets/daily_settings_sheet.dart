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

  Future<void> _pickTime(BuildContext context) async {
    final parts = controller.notifyTime.value
        .split(':')
        .map(int.parse)
        .toList();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (t == null) return;
    await controller.setNotifyTime(
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}',
    );
  }

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
              const SizedBox(height: NuraSpace.s8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Notifikasi harian'),
                value: controller.notifyOn.value,
                onChanged: controller.setNotify,
              ),
              if (controller.notifyDenied.value)
                Text(
                  'Izin notifikasi ditolak, jadi pengingat tidak dikirim. '
                  'Aktifkan izin notifikasi Nura di pengaturan sistem.',
                  style: text.bodySmall,
                ),
              if (controller.notifyFailed.value)
                Text(
                  'Notifikasi harian gagal dijadwalkan. Coba buka ulang Nura.',
                  style: text.bodySmall,
                ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                minTileHeight: 48,
                enabled: controller.notifyOn.value,
                title: const Text('Jam notifikasi'),
                trailing: Text(controller.notifyTime.value),
                onTap: controller.notifyOn.value
                    ? () => _pickTime(context)
                    : null,
              ),
            ],
          );
        }),
      ),
    );
  }
}
