import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/nura_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/prayer_day.dart';
import '../../../data/models/prayer_region.dart';
import '../../../data/models/qari.dart';
import '../../../data/models/daily_content.dart';
import '../../../data/models/reading_prefs.dart';
import '../../prayer/views/prayer_view.dart' show prayerNameLabel;
import '../../prayer/widgets/region_picker_view.dart';
import '../controllers/settings_controller.dart';
import '../widgets/settings_section.dart';

/// Temporary UI (Phase 8 D2): the general-settings design is not made yet.
class SettingsView extends GetView<SettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Pengaturan')),
    body: Obx(
      () => switch (controller.state.value) {
        UiLoading() => const Center(child: CircularProgressIndicator()),
        UiEmpty() => const SizedBox.shrink(),
        UiError(:final message) => ErrorState(
          title: 'Gagal memuat',
          description: message,
          onRetry: controller.load,
        ),
        UiData() => _body(context),
      },
    ),
  );

  Widget _body(BuildContext context) {
    const gap = SizedBox(height: NuraSpace.s24);
    return ListView(
      padding: const EdgeInsets.all(NuraSpace.s16),
      children: [
        SettingsSection(title: 'Tampilan', children: _display(context)),
        gap,
        SettingsSection(title: 'Fitur online', children: _online(context)),
        gap,
        SettingsSection(title: 'Jadwal sholat', children: _prayer(context)),
        gap,
        SettingsSection(title: 'Harian', children: _daily(context)),
        gap,
        SettingsSection(title: 'Tanggal', children: _date(context)),
      ],
    );
  }

  // 48 dp tap target (the default segment is 40).
  static const _segmentStyle = ButtonStyle(
    minimumSize: WidgetStatePropertyAll(Size(0, 48)),
  );

  Widget _label(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.only(top: NuraSpace.s8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NuraSpace.s8),
    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
  );

  List<Widget> _display(BuildContext context) => [
    _label(context, 'Tema'),
    const SizedBox(height: NuraSpace.s8),
    Obx(
      () => SegmentedButton<ThemeMode>(
        style: _segmentStyle,
        showSelectedIcon: true,
        selected: {controller.theme.mode.value},
        onSelectionChanged: (v) => controller.theme.setMode(v.first),
        segments: const [
          ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
          ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
          ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
        ],
      ),
    ),
    Obx(() {
      final p = controller.prefs.value;
      final preview = controller.preview.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (preview != null) ...[
            const SizedBox(height: NuraSpace.s12),
            Text(
              preview.arab,
              textAlign: TextAlign.center,
              textDirection: TextDirection.rtl,
              style: context.nuraText.arabicReading.copyWith(
                fontSize: p.arabicFontSize,
                color: context.nuraColors.arabicText,
              ),
            ),
          ],
          _label(context, 'Ukuran teks Arab'),
          Slider(
            value: p.arabicFontSize.clamp(20, 40),
            min: 20,
            max: 40,
            divisions: 10,
            label: p.arabicFontSize.round().toString(),
            semanticFormatterCallback: (v) => 'Ukuran teks Arab ${v.round()}',
            onChanged: controller.setArabicFontSize,
          ),
          if (preview != null)
            Text(
              preview.translation,
              style: context.nuraText.translation.copyWith(
                fontSize: p.translationFontSize,
              ),
            ),
          _label(context, 'Ukuran teks terjemahan'),
          Slider(
            value: p.translationFontSize.clamp(
              kTranslationFontMin,
              kTranslationFontMax,
            ),
            min: kTranslationFontMin,
            max: kTranslationFontMax,
            divisions: (kTranslationFontMax - kTranslationFontMin).round(),
            label: p.translationFontSize.round().toString(),
            semanticFormatterCallback: (v) =>
                'Ukuran teks terjemahan ${v.round()}',
            onChanged: controller.setTranslationFontSize,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tampilkan terjemahan'),
            value: p.showTranslation,
            onChanged: controller.setShowTranslation,
          ),
        ],
      );
    }),
  ];

  List<Widget> _online(BuildContext context) => [
    Obx(
      () => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Fitur Online'),
        subtitle: const Text(
          'Audio murottal diputar lewat internet (streaming), '
          'tanpa unduhan. Mati secara bawaan.',
        ),
        value: controller.audioOn.value,
        onChanged: controller.setAudioEnabled,
      ),
    ),
    Obx(() {
      if (!controller.audioOn.value) return const SizedBox.shrink();
      final current = controller.qariId.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label(context, 'Qari'),
          for (final q in kQaris)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              title: Text(q.name),
              selected: q.id == current,
              trailing: NuraIcon(
                q.id == current
                    ? NuraIcons.radioChecked
                    : NuraIcons.radioUnchecked,
              ),
              onTap: () => controller.setQari(q.id),
            ),
        ],
      );
    }),
    Obx(
      () => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Unduh jadwal sholat'),
        subtitle: const Text(
          'Jadwal diunduh per bulan dan tersimpan di perangkat.',
        ),
        value: controller.syncOn.value,
        onChanged: controller.setSyncEnabled,
      ),
    ),
  ];

  Future<void> _pickRegion() async {
    final r = await Get.to<PrayerRegion>(
      () => RegionPickerView(regions: controller.regions),
    );
    if (r != null) await controller.selectRegion(r);
  }

  List<Widget> _prayer(BuildContext context) => [
    Obx(() {
      final r = controller.region.value;
      return ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 56,
        leading: const NuraIcon(NuraIcons.locationOn),
        title: const Text('Pilih wilayah'),
        subtitle: Text(
          r == null ? 'Belum dipilih' : '${r.kabkota}, ${r.provinsi}',
        ),
        trailing: const NuraIcon(NuraIcons.chevronRight),
        onTap: _pickRegion,
      );
    }),
    for (final p in PrayerName.values)
      Obx(
        () => SwitchListTile(
          contentPadding: EdgeInsets.zero,
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
      return note == null ? const SizedBox.shrink() : _note(context, note);
    }),
  ];

  static const _sources = [
    (HadithSource.defaultBm, 'Bukhari dan Muslim'),
    (HadithSource.allBooks, 'Sembilan kitab'),
  ];

  Future<void> _pickTime(BuildContext context) async {
    final parts = controller.dailyTime.value.split(':').map(int.parse).toList();
    final t = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: parts[0], minute: parts[1]),
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
        child: child ?? const SizedBox.shrink(),
      ),
    );
    if (t == null) return;
    await controller.setDailyTime(
      '${t.hour.toString().padLeft(2, '0')}:'
      '${t.minute.toString().padLeft(2, '0')}',
    );
  }

  List<Widget> _daily(BuildContext context) => [
    _label(context, 'Sumber hadis'),
    Obx(() {
      final current = controller.hadithSource.value;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (source, label) in _sources)
            ListTile(
              contentPadding: EdgeInsets.zero,
              minTileHeight: 48,
              selected: source == current,
              title: Text(label),
              trailing: source == current
                  ? const NuraIcon(NuraIcons.check)
                  : null,
              onTap: () => controller.setHadithSource(source),
            ),
          if (current == HadithSource.allBooks)
            _note(
              context,
              'Kitab selain Bukhari dan Muslim memuat hadis dengan '
              'derajat yang beragam.',
            ),
        ],
      );
    }),
    Obx(
      () => SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: const Text('Notifikasi harian'),
        value: controller.dailyOn.value,
        onChanged: controller.setDailyNotify,
      ),
    ),
    Obx(() {
      if (controller.dailyDenied.value) {
        return _note(
          context,
          'Izin notifikasi ditolak, jadi pengingat tidak dikirim. '
          'Aktifkan izin notifikasi Nura di pengaturan sistem.',
        );
      }
      if (controller.dailyFailed.value) {
        return _note(
          context,
          'Notifikasi harian gagal dijadwalkan. Coba buka ulang Nura.',
        );
      }
      return const SizedBox.shrink();
    }),
    Obx(
      () => ListTile(
        contentPadding: EdgeInsets.zero,
        minTileHeight: 48,
        enabled: controller.dailyOn.value,
        title: const Text('Jam notifikasi'),
        trailing: Text(controller.dailyTime.value),
        onTap: controller.dailyOn.value ? () => _pickTime(context) : null,
      ),
    ),
  ];

  List<Widget> _date(BuildContext context) => [
    _label(context, 'Penyesuaian tanggal Hijriah'),
    const SizedBox(height: NuraSpace.s8),
    Obx(
      () => SegmentedButton<int>(
        style: _segmentStyle,
        showSelectedIcon: false,
        selected: {controller.hijriAdjust.value},
        onSelectionChanged: (v) => controller.setHijriAdjust(v.first),
        segments: const [
          ButtonSegment(value: -1, label: Text('-1')),
          ButtonSegment(value: 0, label: Text('0')),
          ButtonSegment(value: 1, label: Text('+1')),
        ],
      ),
    ),
    Obx(() => _note(context, 'Hari ini: ${controller.hijriExample.value}')),
  ];
}
