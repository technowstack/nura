import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/repositories/prayer_store.dart';
import 'package:nura/app/modules/prayer/views/prayer_view.dart';
import 'package:nura/app/services/notification_scheduler.dart';
import 'package:nura/app/services/prayer_notifier.dart';

import '../../../support/fake_notifications.dart';
import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart';

Future<(RecordingScheduler, MemoryPrayerStore)> pump(
  WidgetTester tester, {
  double scale = 1,
  PermissionState exact = PermissionState.granted,
  PermissionState afterRequest = PermissionState.granted,
  RecordingScheduler? scheduler,
  Set<PrayerName> preOn = const {},
}) async {
  tester.view.physicalSize = const Size(360, 640);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final sched = (scheduler ?? RecordingScheduler())
    ..exactState = exact
    ..notifAfterRequest = afterRequest
    ..notif = afterRequest == PermissionState.denied
        ? PermissionState.denied
        : PermissionState.granted;
  final store = MemoryPrayerStore(region: jakarta)..on.addAll(preOn);
  setup(
    tester,
    region: jakarta,
    now: DateTime.utc(2026, 11, 15, 1),
    days: {'2026-11-15': api('2026-11-15')},
    beforeController: () {
      store.days['2026-11-15'] = fullDay('2026-11-15');
      Get.put<PrayerNotifier>(
        PrayerNotifier(
          scheduler: sched,
          repository: Get.find<PrayerRepository>(),
          store: store as PrayerStore,
          clock: Get.find<PrayerClock>(),
        ),
      );
    },
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
  await tester.pump();
  return (sched, store);
}

Finder sw(String label) => find.widgetWithText(SwitchListTile, label);

/// Scrolls down until [f] is built (a lazy list does not build items far
/// outside the viewport, so scrollUntilVisible cannot find them).
Future<void> revealBelow(WidgetTester tester, Finder f) async {
  for (var i = 0; i < 20 && f.evaluate().isEmpty; i++) {
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -200));
    await tester.pump();
  }
  await tester.ensureVisible(f);
}

Future<void> reveal(WidgetTester tester, Finder f) async {
  await tester.scrollUntilVisible(
    f,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.ensureVisible(f);
  await tester.pumpAndSettle();
}

void main() {
  tp('five reminder switches, default off, tap targets >= 48', (tester) async {
    await pump(tester);
    for (final p in PrayerName.values) {
      final f = sw('Pengingat ${prayerNameLabel(p)}');
      await reveal(tester, f);
      await tester.pump();
      expect(tester.widget<SwitchListTile>(f).value, isFalse);
      expect(tester.getSize(f).height, greaterThanOrEqualTo(48));
    }
  });

  tp('turning one on stores it and schedules', (tester) async {
    final (sched, store) = await pump(tester);
    final f = sw('Pengingat Subuh');
    await reveal(tester, f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await tester.pump();
    expect(store.on, {PrayerName.subuh});
    expect(tester.widget<SwitchListTile>(f).value, isTrue);
    expect(sched.pending, isEmpty); // 04:30 WIB already past at 08:00
    expect(sched.log, contains('cancel'));
  });

  tp('permission denied: switch stays off and explanation shows', (
    tester,
  ) async {
    final (_, store) = await pump(tester, afterRequest: PermissionState.denied);
    final f = sw('Pengingat Isya');
    await reveal(tester, f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await tester.pump();
    expect(store.on, isEmpty);
    expect(tester.widget<SwitchListTile>(f).value, isFalse);
    await reveal(tester, find.textContaining('Izin notifikasi ditolak'));
    expect(find.textContaining('Izin notifikasi ditolak'), findsOneWidget);
  });

  tp('exact alarm denied shows the late-reminder note', (tester) async {
    await pump(tester, exact: PermissionState.denied);
    final f = sw('Pengingat Isya');
    await reveal(tester, f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await tester.pump();
    await reveal(
      tester,
      find.textContaining('Pengingat bisa terlambat karena'),
    );
    expect(
      find.textContaining('Pengingat bisa terlambat karena'),
      findsOneWidget,
    );
  });

  tp('130% text at 360x640 does not overflow', (tester) async {
    await pump(tester, scale: 1.3, exact: PermissionState.denied);
    final f = sw('Pengingat Isya');
    await reveal(tester, f);
    await tester.pump();
    await tester.tap(f);
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  tp('all schedules failing shows the note; a later success clears it', (
    tester,
  ) async {
    final sched = ThrowingScheduler()..failAll = true;
    await pump(tester, scale: 1.3, scheduler: sched);
    final isya = sw('Pengingat Isya');
    await reveal(tester, isya);
    await tester.tap(isya);
    await tester.pump();
    await tester.pump();
    const note = 'Pengingat gagal dijadwalkan. Coba buka ulang Nura.';
    await revealBelow(tester, find.text(note));
    expect(find.text(note), findsOneWidget);
    expect(tester.takeException(), isNull);
    sched.failAll = false;
    final ashar = sw('Pengingat Ashar');
    await reveal(tester, ashar);
    await tester.tap(ashar);
    await tester.pump();
    await tester.pump();
    expect(find.text(note), findsNothing);
  });

  tp('failure on initial load still shows the stored switches ON', (
    tester,
  ) async {
    final sched = ThrowingScheduler()..failAll = true;
    await pump(tester, scale: 1.3, scheduler: sched, preOn: {PrayerName.isya});
    final isya = sw('Pengingat Isya');
    await reveal(tester, isya);
    expect(tester.widget<SwitchListTile>(isya).value, isTrue);
    await revealBelow(
      tester,
      find.text('Pengingat gagal dijadwalkan. Coba buka ulang Nura.'),
    );
    expect(
      find.text('Pengingat gagal dijadwalkan. Coba buka ulang Nura.'),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  tp('a generic reschedule failure still shows the stored switches ON', (
    tester,
  ) async {
    final sched = ThrowingScheduler()..failCancel = true;
    await pump(tester, scheduler: sched, preOn: {PrayerName.isya});
    final isya = sw('Pengingat Isya');
    await reveal(tester, isya);
    expect(tester.widget<SwitchListTile>(isya).value, isTrue);
  });
}
