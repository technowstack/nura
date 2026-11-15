import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/widgets/next_prayer_card.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/modules/prayer/controllers/prayer_controller.dart';
import 'package:nura/app/modules/prayer/views/prayer_view.dart';

import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart';

Future<Harness> pumpView(
  WidgetTester tester, {
  required Map<String, DayResult> days,
  DateTime? now,
  bool hasRegion = true,
  double scale = 1,
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final h = setup(
    tester,
    region: hasRegion ? jakarta : null,
    now: now ?? DateTime.utc(2026, 11, 15, 1),
    days: days,
  );
  await tester.pumpWidget(
    GetMaterialApp(
      builder: (c, child) => MediaQuery(
        data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
        child: child ?? const SizedBox.shrink(),
      ),
      home: const Scaffold(body: PrayerView()),
    ),
  );
  await tester.pump();
  return h;
}

void main() {
  tp('api day lists times, hides dhuha when null, no perkiraan', (
    tester,
  ) async {
    await pumpView(
      tester,
      days: {'2026-11-15': api('2026-11-15', dhuha: null)},
    );
    for (final l in [
      'Imsak',
      'Subuh',
      'Terbit',
      'Dzuhur',
      'Ashar',
      'Maghrib',
      'Isya',
    ]) {
      expect(find.text(l), findsOneWidget, reason: l);
    }
    expect(find.text('Dhuha'), findsNothing);
    expect(find.text('perkiraan'), findsNothing);
    expect(find.byType(NextPrayerCard), findsOneWidget);
    expect(find.textContaining('Dzuhur  11:50 WIB'), findsOneWidget);
    expect(find.text('dalam 03:50:00'), findsOneWidget);
    expect(find.text('Kota Jakarta, DKI Jakarta'), findsWidgets);
  });

  tp('dhuha row is shown when present', (tester) async {
    await pumpView(tester, days: {'2026-11-15': api('2026-11-15')});
    expect(find.text('Dhuha'), findsOneWidget);
  });

  tp('calc shows the perkiraan label', (tester) async {
    await pumpView(
      tester,
      days: {
        '2026-11-15': DayResult(
          DayOutcome.calc,
          fullDay('2026-11-15', source: PrayerSource.calc),
        ),
      },
    );
    expect(find.text('perkiraan'), findsOneWidget);
  });

  tp('needsInternet message with the sync switch', (tester) async {
    await pumpView(
      tester,
      days: {'2026-11-15': const DayResult(DayOutcome.needsInternet)},
    );
    expect(
      find.text(
        'Aktifkan sinkron jadwal online untuk mengunduh jadwal sholat.',
      ),
      findsOneWidget,
    );
    expect(find.text('Butuh internet untuk jadwal pertama'), findsNothing);
    expect(find.text('Unduh jadwal sholat'), findsOneWidget);
    expect(find.byType(NextPrayerCard), findsNothing);
  });

  tp('needsInternet with sync on keeps the original message', (tester) async {
    final h = await pumpView(
      tester,
      days: {'2026-11-15': const DayResult(DayOutcome.needsInternet)},
    );
    h.repo.syncEnabled = true;
    await h.c.reload();
    await tester.pump();
    expect(find.text('Butuh internet untuk jadwal pertama'), findsOneWidget);
  });

  tp('unknownRegion asks to choose again and offers the picker', (
    tester,
  ) async {
    await pumpView(
      tester,
      days: {'2026-11-15': const DayResult(DayOutcome.unknownRegion)},
    );
    expect(
      find.text('Wilayah ini tidak lagi tersedia. Silakan pilih ulang.'),
      findsOneWidget,
    );
    expect(find.text('Pilih wilayah'), findsOneWidget);
  });

  tp('noData message', (tester) async {
    await pumpView(
      tester,
      days: {'2026-11-15': const DayResult(DayOutcome.noData)},
    );
    expect(find.text('Jadwal bulan ini belum tersedia'), findsOneWidget);
  });

  tp('no region prompts to choose one', (tester) async {
    await pumpView(tester, days: {}, hasRegion: false);
    expect(
      find.text('Pilih wilayah untuk melihat jadwal sholat'),
      findsOneWidget,
    );
    expect(find.text('Pilih wilayah'), findsOneWidget);
  });

  tp('tomorrow unavailable shows the short note', (tester) async {
    await pumpView(
      tester,
      now: DateTime.utc(2026, 11, 15, 13),
      days: {'2026-11-15': api('2026-11-15')},
    );
    expect(find.text('Jadwal besok belum tersedia'), findsOneWidget);
    expect(find.textContaining('dalam '), findsNothing);
  });

  tp('error state offers retry', (tester) async {
    final h = await pumpView(tester, days: {});
    h.repo.failWith = StateError('boom');
    await h.c.reload();
    await tester.pump();
    expect(find.text('Jadwal sholat tidak dapat dimuat.'), findsOneWidget);
    h.repo.failWith = null;
    await tester.tap(find.text('Coba lagi'));
    await tester.pump();
    expect(find.text('Jadwal bulan ini belum tersedia'), findsOneWidget);
  });

  tp('sync switch toggles the setting and is at least 48dp tall', (
    tester,
  ) async {
    final h = await pumpView(tester, days: {'2026-11-15': api('2026-11-15')});
    final tile = find.widgetWithText(SwitchListTile, 'Unduh jadwal sholat');
    expect(tester.getSize(tile).height, greaterThanOrEqualTo(48));
    await tester.ensureVisible(tile);
    await tester.pump();
    await tester.tap(tile);
    await tester.pump();
    expect(h.repo.calls.where((c) => c == 'sync').length, 2);
    expect(h.db.getSetting(SettingKeys.prayerSyncEnabled), 'true');
    expect(Get.find<PrayerController>().screen.value, isNotNull);
  });

  for (final outcome in [DayOutcome.api, DayOutcome.needsInternet]) {
    tp('130% text at 360x640 does not overflow ($outcome)', (tester) async {
      await pumpView(
        tester,
        scale: 1.3,
        days: {
          '2026-11-15': outcome == DayOutcome.api
              ? api('2026-11-15')
              : const DayResult(DayOutcome.needsInternet),
        },
      );
      expect(tester.takeException(), isNull);
    });
  }
}
