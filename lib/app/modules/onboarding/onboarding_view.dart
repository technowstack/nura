import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/notification_notes.dart';
import '../../core/nura_icons.dart';
import '../../core/theme/tokens.dart';
import '../../core/ui_state.dart';
import '../../core/widgets/error_state.dart';
import '../../core/widgets/nura_card.dart';
import 'controllers/onboarding_controller.dart';

/// Temporary UI (no onboarding mock exists yet): three steps, Round 1.5
/// language. Scrolls so 130% text on a small screen never overflows.
class OnboardingView extends GetView<OnboardingController> {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) => Obx(() {
    final c = controller;
    return PopScope(
      // System Back steps back inside the flow; on step 1 it leaves the app.
      canPop: c.isFirst,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) c.back();
      },
      child: Scaffold(
        body: SafeArea(
          child: switch (c.state.value) {
            UiLoading() => const Center(child: CircularProgressIndicator()),
            UiEmpty() => const SizedBox.shrink(),
            UiError(:final message) => ErrorState(
              title: 'Gagal memuat',
              description: message,
              onRetry: c.load,
            ),
            UiData() => _flow(context),
          },
        ),
      ),
    );
  });

  Widget _flow(BuildContext context) {
    final c = controller;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            NuraSpace.s16,
            NuraSpace.s16,
            NuraSpace.s16,
            0,
          ),
          child: Text(
            'Langkah ${c.step.value + 1} dari $kOnboardingSteps',
            style: text.labelLarge,
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(NuraSpace.s16),
            child: switch (c.step.value) {
              0 => _welcome(context),
              1 => _schedule(context),
              _ => _notifications(context),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(NuraSpace.s16),
          child: Wrap(
            alignment: WrapAlignment.end,
            spacing: NuraSpace.s8,
            runSpacing: NuraSpace.s8,
            children: [
              if (!c.isFirst)
                TextButton(onPressed: c.back, child: const Text('Kembali')),
              if (c.isLast) ...[
                TextButton(onPressed: c.finish, child: const Text('Lewati')),
                FilledButton(onPressed: c.finish, child: const Text('Mulai')),
              ] else
                FilledButton(onPressed: c.next, child: const Text('Lanjut')),
            ],
          ),
        ),
      ],
    );
  }

  Widget _title(BuildContext context, String title) => Padding(
    padding: const EdgeInsets.only(bottom: NuraSpace.s12),
    child: Semantics(
      header: true,
      child: Text(title, style: Theme.of(context).textTheme.headlineSmall),
    ),
  );

  Widget _note(BuildContext context, String text) => Padding(
    padding: const EdgeInsets.symmetric(vertical: NuraSpace.s8),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );

  Widget _welcome(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(context, 'Selamat datang di Nura'),
      _note(
        context,
        'Al-Qur\'an, hadis, dan jadwal sholat dalam satu aplikasi.',
      ),
      _note(context, 'Al-Qur\'an dan hadis bisa dibaca tanpa internet.'),
      _note(
        context,
        'Audio murottal lewat internet bisa diaktifkan di Pengaturan.',
      ),
    ],
  );

  Widget _schedule(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(context, 'Jadwal sholat'),
      NuraCard(
        padding: const EdgeInsets.symmetric(
          horizontal: NuraSpace.s16,
          vertical: NuraSpace.s8,
        ),
        child: Column(
          children: [
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
                onTap: controller.pickRegion,
              );
            }),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Unduh jadwal sholat'),
                subtitle: const Text(
                  'Setelah Lanjut, wilayah yang dipilih dikirim ke equran.id '
                  'untuk mengunduh jadwal bulanan, lalu disimpan di perangkat.',
                ),
                value: controller.syncOn.value,
                onChanged: controller.setSyncEnabled,
              ),
            ),
          ],
        ),
      ),
      _note(
        context,
        'Tanpa unduhan, jadwal sholat belum bisa ditampilkan. '
        'Jadwal bisa diunduh nanti di Pengaturan.',
      ),
      Obx(
        () => controller.remindersFailed.value
            ? _note(context, kRemindersFailedNote)
            : const SizedBox.shrink(),
      ),
    ],
  );

  Widget _notifications(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      _title(context, 'Notifikasi'),
      _note(
        context,
        'Izin notifikasi hanya diminta saat Anda menyalakan salah satu '
        'pengingat. Sistem juga bisa membuka halaman "Alarm & pengingat" '
        'agar pengingat adzan tepat waktu. Langkah ini boleh dilewati.',
      ),
      NuraCard(
        padding: const EdgeInsets.symmetric(
          horizontal: NuraSpace.s16,
          vertical: NuraSpace.s8,
        ),
        child: Column(
          children: [
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pengingat adzan'),
                subtitle: const Text('Lima waktu sholat.'),
                value: controller.prayerOn.value,
                onChanged: controller.setPrayerReminders,
              ),
            ),
            Obx(
              () => SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ayat & hadis harian'),
                subtitle: Text(
                  'Setiap hari pukul '
                  '${controller.dailyTime.value.replaceAll(':', '.')}. '
                  'Jam bisa diubah di Pengaturan.',
                ),
                value: controller.dailyOn.value,
                onChanged: controller.setDailyNotify,
              ),
            ),
          ],
        ),
      ),
      Obx(() {
        final c = controller;
        final note = c.denied.value
            ? kNotificationDeniedNote
            : c.remindersFailed.value
            ? kRemindersFailedNote
            : c.dailyFailed.value
            ? kDailyFailedNote
            : c.exactDenied.value
            ? kExactDeniedNote
            : null;
        return note == null ? const SizedBox.shrink() : _note(context, note);
      }),
    ],
  );
}
