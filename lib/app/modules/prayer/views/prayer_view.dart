import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/tokens.dart';
import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../core/widgets/next_prayer_card.dart';
import '../../../data/models/prayer_day.dart';
import '../../../data/models/prayer_region.dart';
import '../../../data/repositories/prayer_repository.dart';
import '../controllers/prayer_controller.dart';
import '../widgets/prayer_time_row.dart';
import '../widgets/region_picker_view.dart';

String prayerNameLabel(PrayerName p) => switch (p) {
  PrayerName.subuh => 'Subuh',
  PrayerName.dzuhur => 'Dzuhur',
  PrayerName.ashar => 'Ashar',
  PrayerName.maghrib => 'Maghrib',
  PrayerName.isya => 'Isya',
};

class PrayerView extends GetView<PrayerController> {
  const PrayerView({super.key});

  Future<void> _pick() async {
    final r = await Get.to<PrayerRegion>(
      () => RegionPickerView(regions: controller.regions),
    );
    if (r != null) await controller.selectRegion(r);
  }

  @override
  Widget build(BuildContext context) => Obx(
    () => switch (controller.screen.value) {
      UiLoading() => const Center(child: CircularProgressIndicator()),
      UiEmpty() => EmptyState(
        title: 'Pilih wilayah untuk melihat jadwal sholat',
        action: FilledButton(
          onPressed: _pick,
          style: FilledButton.styleFrom(minimumSize: const Size(48, 48)),
          child: const Text('Pilih wilayah'),
        ),
      ),
      UiError(:final message) => ErrorState(
        title: 'Gagal memuat',
        description: message,
        onRetry: controller.reload,
      ),
      UiData(:final value) => _body(value),
    },
  );

  Widget _body(PrayerScreen s) {
    final day = s.day;
    return ListView(
      children: [
        if (day != null) ...[
          _card(s),
          for (final row in _rows(s, day))
            PrayerTimeRow(label: row.$1, time: row.$2, highlighted: row.$3),
        ] else ...[
          Padding(
            padding: const EdgeInsets.all(NuraSpace.s16),
            child: Text(_message(s), style: Get.textTheme.titleMedium),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: NuraSpace.s16),
            child: Text(s.regionLabel, style: Get.textTheme.bodyMedium),
          ),
        ],
        const Divider(),
        SwitchListTile(
          value: s.syncEnabled,
          onChanged: controller.setSyncEnabled,
          title: const Text('Unduh jadwal sholat'),
          subtitle: const Text(
            'Jadwal diunduh per bulan dan tersimpan di perangkat.',
          ),
        ),
        ListTile(
          minTileHeight: 56,
          leading: const Icon(Icons.place_outlined),
          title: const Text('Pilih wilayah'),
          subtitle: Text(s.regionLabel),
          trailing: const Icon(Icons.chevron_right),
          onTap: _pick,
        ),
        const Divider(),
        ..._reminders(),
      ],
    );
  }

  List<Widget> _reminders() => [
    for (final p in PrayerName.values)
      Obx(
        () => SwitchListTile(
          value: controller.notifyOn[p] ?? false,
          onChanged: (v) => controller.setNotify(p, v),
          title: Text('Pengingat ${prayerNameLabel(p)}'),
        ),
      ),
    Obx(() {
      final note = controller.remindersFailed.value
          ? 'Pengingat gagal dijadwalkan. Coba buka ulang Nura.'
          : controller.notifyDenied.value
          ? 'Izin notifikasi ditolak, jadi pengingat tidak dikirim. '
                'Aktifkan izin notifikasi Nura di pengaturan sistem.'
          : controller.exactDenied.value
          ? 'Pengingat bisa terlambat beberapa menit karena izin alarm '
                'tepat belum diberikan.'
          : null;
      if (note == null) return const SizedBox.shrink();
      return Padding(
        padding: const EdgeInsets.all(NuraSpace.s16),
        child: Text(note, style: Get.textTheme.bodyMedium),
      );
    }),
  ];

  Widget _card(PrayerScreen s) {
    final next = s.next;
    if (next == null) {
      return NextPrayerCard(
        name: '-',
        time: '',
        regionLabel: s.regionLabel,
        zoneLabel: s.zoneLabel,
        estimated: s.estimated,
        note: 'Jadwal besok belum tersedia',
      );
    }
    final at = s.nextAt;
    // Region-local HH:mm of the next prayer.
    final local = at?.add(Duration(hours: s.region.zone.offsetHours));
    final time = local == null
        ? ''
        : '${local.hour.toString().padLeft(2, '0')}:'
              '${local.minute.toString().padLeft(2, '0')}';
    return Obx(
      () => NextPrayerCard(
        name: prayerNameLabel(next),
        time: time,
        regionLabel: s.regionLabel,
        zoneLabel: s.zoneLabel,
        countdown: controller.countdown.value,
        estimated: s.estimated,
      ),
    );
  }

  List<(String, String, bool)> _rows(PrayerScreen s, PrayerDay d) {
    bool hi(PrayerName p) => !s.nextIsTomorrow && s.next == p;
    final all = <(String, String?, bool)>[
      ('Imsak', d.imsak, false),
      ('Subuh', d.subuh, hi(PrayerName.subuh)),
      ('Terbit', d.terbit, false),
      ('Dhuha', d.dhuha, false),
      ('Dzuhur', d.dzuhur, hi(PrayerName.dzuhur)),
      ('Ashar', d.ashar, hi(PrayerName.ashar)),
      ('Maghrib', d.maghrib, hi(PrayerName.maghrib)),
      ('Isya', d.isya, hi(PrayerName.isya)),
    ];
    return [
      for (final (l, t, h) in all)
        if (t != null) (l, t, h),
    ];
  }

  String _message(PrayerScreen s) => switch (s.outcome) {
    DayOutcome.needsInternet =>
      s.syncEnabled
          ? 'Butuh internet untuk jadwal pertama'
          : 'Aktifkan sinkron jadwal online untuk mengunduh jadwal sholat.',
    DayOutcome.unknownRegion =>
      'Wilayah ini tidak lagi tersedia. Silakan pilih ulang.',
    DayOutcome.noRegion => 'Pilih wilayah untuk melihat jadwal sholat',
    DayOutcome.noData => 'Jadwal bulan ini belum tersedia',
    DayOutcome.api || DayOutcome.calc => 'Jadwal belum tersedia',
  };
}
