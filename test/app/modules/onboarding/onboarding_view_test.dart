import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/modules/onboarding/bindings/onboarding_binding.dart';
import 'package:nura/app/modules/onboarding/controllers/onboarding_controller.dart';
import 'package:nura/app/modules/onboarding/onboarding_view.dart';
import 'package:nura/app/routes/app_routes.dart';
import 'package:nura/app/services/notification_scheduler.dart';

import '../../../support/settings_harness.dart';

Future<SettingsHarness> open(
  WidgetTester t, {
  double scale = 1,
  ThemeMode mode = ThemeMode.light,
  PermissionState notif = PermissionState.granted,
  PermissionState afterRequest = PermissionState.granted,
}) async {
  t.view.physicalSize = const Size(360, 640);
  t.view.devicePixelRatio = 1;
  addTearDown(t.view.reset);
  final h = SettingsHarness.create();
  h.scheduler.notif = notif;
  h.scheduler.notifAfterRequest = afterRequest;
  Get.put<UserDatabase>(h.db);
  await t.pumpWidget(
    GetMaterialApp(
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      initialRoute: Routes.onboarding,
      getPages: [
        GetPage(
          name: Routes.onboarding,
          page: OnboardingView.new,
          binding: OnboardingBinding(),
        ),
        GetPage(
          name: Routes.home,
          page: () => const Scaffold(body: Text('HOME')),
        ),
      ],
    ),
  );
  await pumpSettled(t);
  return h;
}

Future<void> tapText(WidgetTester t, String s) async {
  await t.tap(find.text(s));
  await pumpSettled(t);
}

void main() {
  testWidgets('three steps in order; welcome mentions audio in Pengaturan', (
    t,
  ) async {
    await open(t);
    expect(find.text('Langkah 1 dari 3'), findsOneWidget);
    expect(find.text('Selamat datang di Nura'), findsOneWidget);
    expect(find.textContaining('Pengaturan'), findsOneWidget);
    expect(
      find.text("Al-Qur'an dan hadis bisa dibaca tanpa internet."),
      findsOneWidget,
    );
    expect(find.text('Kembali'), findsNothing);
    await tapText(t, 'Lanjut');
    expect(find.text('Jadwal sholat'), findsOneWidget);
    expect(
      find.text(
        'Tanpa unduhan, jadwal sholat belum bisa ditampilkan. '
        'Jadwal bisa diunduh nanti di Pengaturan.',
      ),
      findsOneWidget,
    );
    expect(find.textContaining('perkiraan'), findsNothing);
    expect(find.textContaining('perhitungan di perangkat'), findsNothing);
    expect(find.text('Kembali'), findsOneWidget);
    await tapText(t, 'Lanjut');
    expect(find.text('Notifikasi'), findsOneWidget);
    expect(find.text('Lewati'), findsOneWidget);
    expect(find.text('Mulai'), findsOneWidget);
    expect(find.text('Lanjut'), findsNothing);
    await tapText(t, 'Kembali');
    expect(find.text('Jadwal sholat'), findsOneWidget);
  });

  testWidgets('no Fitur Online switch; download is on but unwritten', (
    t,
  ) async {
    final h = await open(t);
    await tapText(t, 'Lanjut');
    expect(find.text('Fitur Online'), findsNothing);
    expect(find.text('Unduh jadwal sholat'), findsOneWidget);
    expect(tester(t, find.byType(SwitchListTile)).first.value, isTrue);
    expect(
      find.text(
        'Setelah Lanjut, wilayah yang dipilih dikirim ke equran.id untuk '
        'mengunduh jadwal bulanan, lalu disimpan di perangkat.',
      ),
      findsOneWidget,
    );
    expect(h.db.getSetting('prayer_sync_enabled'), isNull);
    expect(h.db.getSetting('online_enabled'), isNull);
    expect(h.db.getSetting('onboarding_done'), isNull);
  });

  testWidgets('region picker round trip keeps the controller alive', (t) async {
    final h = await open(t);
    await tapText(t, 'Lanjut');
    await tapText(t, 'Pilih wilayah');
    expect(find.text('DKI Jakarta'), findsOneWidget);
    await tapText(t, 'DKI Jakarta');
    await tapText(t, 'Kota Jakarta');
    await t.pump(const Duration(seconds: 1)); // pop transition
    expect(Get.isRegistered<OnboardingController>(), isTrue);
    expect(find.text('Kota Jakarta, DKI Jakarta'), findsOneWidget);
    expect(h.prayer.region?.kabkota, 'Kota Jakarta');
    // Back and forth still works after the picker route popped.
    await tapText(t, 'Kembali');
    await tapText(t, 'Lanjut');
    expect(find.text('Kota Jakarta, DKI Jakarta'), findsOneWidget);
  });

  testWidgets('the download switch is written only on Lanjut', (t) async {
    final h = await open(t);
    await tapText(t, 'Lanjut');
    await t.tap(find.byType(SwitchListTile));
    await pumpSettled(t);
    expect(
      t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
      isFalse,
    );
    expect(h.db.getSetting('prayer_sync_enabled'), isNull);
    await tapText(t, 'Lanjut');
    expect(h.db.getSetting('prayer_sync_enabled'), 'false');
    expect(h.db.getSetting('online_enabled'), isNull);
    expect(h.db.getSetting('onboarding_done'), isNull);
  });

  testWidgets('denied permission: switch off, note shown, can finish', (
    t,
  ) async {
    final h = await open(
      t,
      notif: PermissionState.denied,
      afterRequest: PermissionState.denied,
    );
    await tapText(t, 'Lanjut');
    await tapText(t, 'Lanjut');
    expect(h.scheduler.log, isNot(contains('requestNotif')));
    await t.tap(find.widgetWithText(SwitchListTile, 'Pengingat adzan'));
    await pumpSettled(t);
    expect(h.scheduler.log, contains('requestNotif'));
    expect(find.textContaining('Izin notifikasi ditolak'), findsOneWidget);
    final sw = t.widget<SwitchListTile>(
      find.widgetWithText(SwitchListTile, 'Pengingat adzan'),
    );
    expect(sw.value, isFalse);
    await tapText(t, 'Lewati');
    expect(find.text('HOME'), findsOneWidget);
    expect(h.db.getSetting('onboarding_done'), 'true');
  });

  testWidgets('granted: both reminders on; Mulai finishes, Back stays home', (
    t,
  ) async {
    final h = await open(t);
    await tapText(t, 'Lanjut');
    await tapText(t, 'Lanjut');
    await t.tap(find.widgetWithText(SwitchListTile, 'Pengingat adzan'));
    await pumpSettled(t);
    await t.ensureVisible(find.text('Ayat & hadis harian'));
    await t.pump();
    await t.tap(find.widgetWithText(SwitchListTile, 'Ayat & hadis harian'));
    await pumpSettled(t);
    for (final p in PrayerName.values) {
      expect(h.prayerNotifier.isEnabled(p), isTrue);
    }
    expect(h.daily.notifyEnabled, isTrue);
    expect(find.textContaining('06.00'), findsOneWidget);
    await tapText(t, 'Mulai');
    expect(find.text('HOME'), findsOneWidget);
    expect(Get.currentRoute, Routes.home);
    await t.pump(const Duration(seconds: 1));
    expect(Get.isRegistered<OnboardingController>(), isFalse);
    await Get.key.currentState!.maybePop();
    await pumpSettled(t);
    expect(find.text('HOME'), findsOneWidget);
    expect(h.db.getSetting('onboarding_done'), 'true');
  });

  testWidgets('step 3 announces the alarm page and notes a denial', (t) async {
    final h = await open(t);
    h.scheduler.exactState = PermissionState.denied;
    await tapText(t, 'Lanjut');
    await tapText(t, 'Lanjut');
    expect(find.textContaining('"Alarm & pengingat"'), findsOneWidget);
    expect(find.textContaining('izin alarm tepat'), findsNothing);
    await tapText(t, 'Pengingat adzan');
    expect(
      find.text(
        'Pengingat bisa terlambat karena izin alarm tepat belum diberikan.',
      ),
      findsOneWidget,
    );
  });

  testWidgets('system Back steps back inside the flow', (t) async {
    await open(t);
    await tapText(t, 'Lanjut');
    await Get.key.currentState!.maybePop();
    await pumpSettled(t);
    expect(find.text('Selamat datang di Nura'), findsOneWidget);
  });

  for (final mode in [ThemeMode.light, ThemeMode.dark]) {
    testWidgets('130% text at 360x640 scrolls without overflow ($mode)', (
      t,
    ) async {
      await open(t, scale: 1.3, mode: mode);
      for (var i = 0; i < 3; i++) {
        expect(t.takeException(), isNull);
        for (final b in [
          ...t.widgetList<ButtonStyleButton>(find.byType(ButtonStyleButton)),
        ]) {
          expect(b.onPressed, isNotNull);
        }
        for (final f in find.byType(ButtonStyleButton).evaluate()) {
          expect(
            t.getSize(find.byWidget(f.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        for (final s in find.byType(SwitchListTile).evaluate()) {
          expect(
            t.getSize(find.byWidget(s.widget)).height,
            greaterThanOrEqualTo(48),
          );
        }
        if (i < 2) await tapText(t, 'Lanjut');
      }
    });
  }
}

List<SwitchListTile> tester(WidgetTester t, Finder f) =>
    t.widgetList<SwitchListTile>(f).toList();
