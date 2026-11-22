import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';
import 'package:nura/app/modules/settings/views/settings_view.dart';
import 'package:nura/app/services/notification_scheduler.dart';

import '../../../support/prayer_harness.dart' show jakarta;
import '../../../support/settings_harness.dart';

const _denied =
    'Izin notifikasi ditolak, jadi pengingat tidak dikirim. '
    'Aktifkan izin notifikasi Nura di pengaturan sistem.';
const _notice =
    'Kitab selain Bukhari dan Muslim memuat hadis dengan '
    'derajat yang beragam.';

void main() {
  late SettingsHarness h;

  setUp(() => h = SettingsHarness.create());

  Future<SettingsController> pump(
    WidgetTester t, {
    double scale = 1,
    ThemeData? theme,
  }) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = h.controller();
    await t.pumpWidget(
      Obx(
        () => GetMaterialApp(
          theme: theme ?? AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: h.theme.mode.value,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child ?? const SizedBox.shrink(),
          ),
          home: const SettingsView(),
        ),
      ),
    );
    await t.pump();
    await t.pump();
    await pumpSettled(t);
    return c;
  }

  // The list builds lazily, so scroll to rows that are not built yet.
  Future<void> show(WidgetTester t, Finder f) async {
    final scrollable = find.byType(Scrollable).first;
    if (f.evaluate().isEmpty) {
      try {
        await t.scrollUntilVisible(f, 150, scrollable: scrollable);
      } on StateError {
        await t.scrollUntilVisible(f, -150, scrollable: scrollable);
      }
    } else {
      await t.ensureVisible(f);
    }
    await t.pump();
  }

  Future<void> tapText(WidgetTester t, String text) async {
    final f = find.text(text);
    await show(t, f);
    await t.tap(f);
    await pumpSettled(t);
  }

  double sizeOf(WidgetTester t, String text) =>
      t.widget<Text>(find.text(text)).style!.fontSize!;

  testWidgets('shows every section title; loading first', (t) async {
    t.view.physicalSize = const Size(360, 640);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    final c = h.controller();
    expect(c.state.value, isA<UiLoading<void>>());
    await t.pumpWidget(const GetMaterialApp(home: SettingsView()));
    await t.pump();
    await t.pump();
    for (final s in ['Tampilan', 'Fitur online', 'Jadwal sholat', 'Harian']) {
      await show(t, find.text(s));
      expect(find.text(s), findsOneWidget);
    }
    await show(t, find.text('Tanggal'));
    expect(find.text('Tanggal'), findsOneWidget);
    expect(find.text('Tentang'), findsNothing);
  });

  testWidgets('store error shows the error state; retry recovers', (t) async {
    h.user.prefsFailure = StateError('x');
    await pump(t);
    expect(find.text('Pengaturan tidak dapat dimuat.'), findsOneWidget);
    h.user.prefsFailure = null;
    await t.tap(find.text('Coba lagi'));
    await t.pump();
    await t.pump();
    expect(find.text('Tampilan'), findsOneWidget);
  });

  group('Tampilan', () {
    testWidgets('Arab slider: 20..40, live preview, persists', (t) async {
      await pump(t);
      final slider = t.widget<Slider>(find.byType(Slider).first);
      expect((slider.min, slider.max, slider.divisions), (20, 40, 10));
      expect(sizeOf(t, 'بِسْمِ ٱللَّهِ'), 28);
      slider.onChanged!(36);
      await t.pump();
      expect(h.user.prefs.arabicFontSize, 36);
      expect(sizeOf(t, 'بِسْمِ ٱللَّهِ'), 36);
      expect(
        t.widget<Text>(find.text('بِسْمِ ٱللَّهِ')).style!.fontFamily,
        'Scheherazade New',
      );
    });

    testWidgets('translation slider: 14..22, live preview, persists', (
      t,
    ) async {
      await pump(t);
      final slider = t.widget<Slider>(find.byType(Slider).last);
      expect((slider.min, slider.max, slider.divisions), (14, 22, 8));
      expect(sizeOf(t, 'Dengan nama Allah'), 15);
      slider.onChanged!(20);
      await t.pump();
      expect(h.user.prefs.translationFontSize, 20);
      expect(sizeOf(t, 'Dengan nama Allah'), 20);
    });

    testWidgets('translation switch persists', (t) async {
      await pump(t);
      await tapText(t, 'Tampilkan terjemahan');
      expect(h.user.prefs.showTranslation, isFalse);
      expect(t.widget<Switch>(find.byType(Switch).first).value, isFalse);
    });

    testWidgets('theme: Gelap applies to the app and persists', (t) async {
      await pump(t);
      expect(find.byIcon(Icons.check), findsOneWidget);
      await tapText(t, 'Gelap');
      expect(
        t.widget<GetMaterialApp>(find.byType(GetMaterialApp)).themeMode,
        ThemeMode.dark,
      );
      expect(h.user.themeMode, ThemeMode.dark);
    });

    testWidgets('a failed save leaves the size unchanged', (t) async {
      await pump(t);
      h.user.failure = StateError('disk');
      t.widget<Slider>(find.byType(Slider).last).onChanged!(20);
      await t.pump();
      expect(sizeOf(t, 'Dengan nama Allah'), 15);
      await t.pump(const Duration(seconds: 3));
    });
  });

  group('Fitur online', () {
    testWidgets('qari picker only while the switch is on', (t) async {
      await pump(t);
      expect(find.text('Qari'), findsNothing);
      await tapText(t, 'Fitur Online');
      expect(h.online.audioEnabled, isTrue);
      expect(find.text('Qari'), findsOneWidget);
      await tapText(t, 'Abdurrahman As-Sudais');
      expect(h.db.getSetting('qari_id'), '03');
      await tapText(t, 'Fitur Online');
      expect(find.text('Qari'), findsNothing);
      expect(h.online.audioEnabled, isFalse);
    });

    testWidgets('sync switch writes prayer_sync_enabled', (t) async {
      await pump(t);
      await tapText(t, 'Unduh jadwal sholat');
      expect(h.online.prayerSyncEnabled, isTrue);
    });
  });

  group('Jadwal sholat', () {
    testWidgets('region row shows the region and opens the picker', (t) async {
      h.prayer.region = jakarta;
      await pump(t);
      await show(t, find.text('Kota Jakarta, DKI Jakarta'));
      expect(find.text('Kota Jakarta, DKI Jakarta'), findsOneWidget);
      await show(t, find.text('Pilih wilayah'));
      await t.tap(find.text('Pilih wilayah'));
      await t.pumpAndSettle();
      expect(find.text('Cari kota atau kabupaten'), findsOneWidget);
      await t.tap(find.text('Sulawesi Selatan'));
      await t.pumpAndSettle();
      await t.tap(find.text('Kota Makassar'));
      await t.pumpAndSettle();
      await pumpSettled(t);
      expect(h.prayer.region?.kabkota, 'Kota Makassar');
      expect(find.text('Kota Makassar, Sulawesi Selatan'), findsOneWidget);
    });

    testWidgets('no region reads Belum dipilih', (t) async {
      await pump(t);
      await show(t, find.text('Belum dipilih'));
      expect(find.text('Belum dipilih'), findsOneWidget);
    });

    testWidgets('reminder switch persists; denied shows the note', (t) async {
      await pump(t);
      await tapText(t, 'Pengingat Subuh');
      expect(h.prayerStore.on, {PrayerName.subuh});
      h.scheduler
        ..notif = PermissionState.denied
        ..notifAfterRequest = PermissionState.denied;
      await tapText(t, 'Pengingat Isya');
      // Already one reminder on and permission now denied: refused.
      expect(h.prayerStore.on.contains(PrayerName.isya), isFalse);
      expect(find.text(_denied), findsOneWidget);
    });

    testWidgets('denied when none is on: switch stays off with the note', (
      t,
    ) async {
      h.scheduler
        ..notif = PermissionState.denied
        ..notifAfterRequest = PermissionState.denied;
      await pump(t);
      await tapText(t, 'Pengingat Subuh');
      expect(h.prayerStore.on, isEmpty);
      expect(find.text(_denied), findsOneWidget);
      expect(
        t
            .widget<SwitchListTile>(
              find.widgetWithText(SwitchListTile, 'Pengingat Subuh'),
            )
            .value,
        isFalse,
      );
    });
  });

  group('Harian', () {
    testWidgets('9 books note only when selected; source persists', (t) async {
      await pump(t);
      await show(t, find.text('Sembilan kitab'));
      expect(find.text(_notice), findsNothing);
      await tapText(t, 'Sembilan kitab');
      expect(find.text(_notice), findsOneWidget);
      expect(h.daily.hadithSource, HadithSource.allBooks);
      expect(h.renders, 1);
      await tapText(t, 'Bukhari dan Muslim');
      expect(find.text(_notice), findsNothing);
      expect(h.daily.hadithSource, HadithSource.defaultBm);
    });

    testWidgets('switch schedules seven days; time row enables', (t) async {
      await pump(t);
      await show(t, find.text('Jam notifikasi'));
      expect(
        t
            .widget<ListTile>(find.widgetWithText(ListTile, 'Jam notifikasi'))
            .enabled,
        isFalse,
      );
      await tapText(t, 'Notifikasi harian');
      expect(h.daily.notifyEnabled, isTrue);
      expect(h.scheduler.pending.length, 7);
      expect(
        t
            .widget<ListTile>(find.widgetWithText(ListTile, 'Jam notifikasi'))
            .enabled,
        isTrue,
      );
      expect(find.text('06:00'), findsOneWidget);
    });

    testWidgets('denied keeps the switch off and shows the note', (t) async {
      h.scheduler
        ..notif = PermissionState.denied
        ..notifAfterRequest = PermissionState.denied;
      await pump(t);
      await tapText(t, 'Notifikasi harian');
      expect(h.daily.notifyEnabled, isFalse);
      expect(h.scheduler.pending, isEmpty);
      expect(find.text(_denied), findsOneWidget);
    });

    testWidgets('failed scheduling flags the note', (t) async {
      h.scheduler.failAll = true;
      await pump(t);
      await tapText(t, 'Notifikasi harian');
      expect(
        find.text('Notifikasi harian gagal dijadwalkan. Coba buka ulang Nura.'),
        findsOneWidget,
      );
    });

    testWidgets('time picker: cancel keeps the time, OK stores HH:mm', (
      t,
    ) async {
      h.daily
        ..notifyEnabled = true
        ..notifyTime = '07:05';
      await pump(t);
      await tapText(t, 'Jam notifikasi');
      await t.pumpAndSettle();
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      expect(h.daily.notifyTime, '07:05');
      expect(h.scheduler.log, isNot(contains('cancelDaily')));
      await tapText(t, 'Jam notifikasi');
      await t.pumpAndSettle();
      await t.tap(find.text('OK'));
      await pumpSettled(t);
      expect(h.daily.notifyTime, '07:05');
      expect(h.scheduler.log, contains('cancelDaily'));
    });
  });

  group('Tanggal', () {
    testWidgets('adjustment persists and the example follows', (t) async {
      await pump(t);
      await show(t, find.text('Penyesuaian tanggal Hijriah'));
      final base = h.hijri.format(DateTime(2026, 11, 15));
      expect(find.text('Hari ini: $base'), findsOneWidget);
      await tapText(t, '+1');
      expect(h.db.getSetting('hijri_adjust'), '1');
      expect(find.text('Hari ini: $base'), findsNothing);
      expect(
        find.text('Hari ini: ${h.hijri.format(DateTime(2026, 11, 15))}'),
        findsOneWidget,
      );
      await tapText(t, '0');
      expect(find.text('Hari ini: $base'), findsOneWidget);
    });
  });

  for (final dark in [false, true]) {
    testWidgets(
      '130% text at 360x640: scrolls, no overflow, 48dp (dark=$dark)',
      (t) async {
        h.daily.notifyEnabled = true;
        h.scheduler
          ..notif = PermissionState.denied
          ..notifAfterRequest = PermissionState.denied;
        await pump(t, scale: 1.3, theme: dark ? AppTheme.dark : AppTheme.light);
        await tapText(t, 'Fitur Online');
        await tapText(t, 'Sembilan kitab');
        await tapText(t, 'Pengingat Subuh');
        expect(find.byType(ListView), findsOneWidget);
        expect(t.takeException(), isNull);
        for (final f in [
          find.widgetWithText(SwitchListTile, 'Tampilkan terjemahan'),
          find.widgetWithText(SwitchListTile, 'Fitur Online'),
          find.widgetWithText(ListTile, 'Pilih wilayah'),
          find.widgetWithText(ListTile, 'Sembilan kitab'),
          find.widgetWithText(ListTile, 'Jam notifikasi'),
          find.widgetWithText(ListTile, 'Abdurrahman As-Sudais'),
        ]) {
          await show(t, f);
          expect(t.getSize(f).height, greaterThanOrEqualTo(48));
        }
        await show(t, find.text('0'));
        expect(t.getSize(find.text('0')).height, greaterThan(0));
        expect(
          t.getSize(find.widgetWithText(SegmentedButton<int>, '0')).height,
          greaterThanOrEqualTo(40),
        );
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets('prayer reminders list has all five prayers', (t) async {
    await pump(t);
    for (final p in PrayerName.values) {
      final f = find.widgetWithText(SwitchListTile, 'Pengingat ${_label(p)}');
      await show(t, f);
      expect(f, findsOneWidget);
    }
  });
}

String _label(PrayerName p) => switch (p) {
  PrayerName.subuh => 'Subuh',
  PrayerName.dzuhur => 'Dzuhur',
  PrayerName.ashar => 'Ashar',
  PrayerName.maghrib => 'Maghrib',
  PrayerName.isya => 'Isya',
};
