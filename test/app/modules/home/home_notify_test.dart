import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/modules/home/widgets/daily_settings_sheet.dart';
import 'package:nura/app/services/daily_notifier.dart';
import 'package:nura/app/services/notification_scheduler.dart';

import '../../../support/fake_daily.dart';
import '../../../support/fake_notifications.dart';

const _denied =
    'Izin notifikasi ditolak, jadi pengingat tidak dikirim. '
    'Aktifkan izin notifikasi Nura di pengaturan sistem.';
const _failed = 'Notifikasi harian gagal dijadwalkan. Coba buka ulang Nura.';

void main() {
  late ThrowingScheduler sch;
  late FakeDailySettingsStore store;
  late DateTime now;

  setUp(() {
    Get.reset();
    sch = ThrowingScheduler();
    store = FakeDailySettingsStore();
    now = DateTime(2026, 11, 15, 5);
    Get.put<DailyContentRepository>(FakeDailyContentRepository());
    Get.put<DailySettingsStore>(store);
    Get.put<DailyNotifier>(
      DailyNotifier(
        scheduler: sch,
        repository: Get.find(),
        store: store,
        now: () => now,
      ),
    );
  });
  tearDown(Get.reset);

  Future<HomeController> pump(WidgetTester tester, {double scale = 1}) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final c = Get.put(HomeController(now: () => now));
    await tester.pumpWidget(
      GetMaterialApp(
        theme: AppTheme.light,
        builder: (ctx, child) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: child ?? const SizedBox.shrink(),
        ),
        home: const Scaffold(body: DailySettingsSheet()),
      ),
    );
    await tester.pump();
    return c;
  }

  // Lets the notifier's future chain finish, then rebuilds.
  Future<void> settle(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await t.pump();
  }

  void tw(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        await tester.pumpWidget(const SizedBox.shrink());
        Get.delete<HomeController>(force: true);
      });

  tw('switch on schedules seven days; time row enabled', (tester) async {
    await pump(tester);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Jam notifikasi'))
          .enabled,
      isFalse,
    );
    await tester.tap(find.text('Notifikasi harian'));
    await settle(tester);
    expect(store.notifyEnabled, isTrue);
    expect(sch.pending.length, 7);
    expect(
      tester
          .widget<ListTile>(find.widgetWithText(ListTile, 'Jam notifikasi'))
          .enabled,
      isTrue,
    );
    expect(find.text('06:00'), findsOneWidget);
  });

  tw('denied keeps the switch off and shows the note', (tester) async {
    sch.notif = PermissionState.denied;
    sch.notifAfterRequest = PermissionState.denied;
    await pump(tester);
    await tester.tap(find.text('Notifikasi harian'));
    await settle(tester);
    expect(store.notifyEnabled, isFalse);
    expect(sch.pending, isEmpty);
    expect(find.text(_denied), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isFalse);
  });

  tw('all-fail shows the flag, keeps switch state, later success clears', (
    tester,
  ) async {
    sch.failAll = true;
    final c = await pump(tester);
    await tester.tap(find.text('Notifikasi harian'));
    await settle(tester);
    expect(c.notifyFailed.value, isTrue);
    expect(find.text(_failed), findsOneWidget);
    expect(tester.widget<Switch>(find.byType(Switch)).value, isTrue);
    sch.failAll = false;
    await tester.runAsync(() => c.setNotifyTime('07:00'));
    await tester.pump();
    expect(find.text(_failed), findsNothing);
    expect(find.text('07:00'), findsOneWidget);
  });

  tw('time row is a 48dp target and 130% text does not overflow', (
    tester,
  ) async {
    final c = await pump(tester, scale: 1.3);
    await tester.runAsync(() => c.setNotify(true));
    await tester.pump();
    final row = find.widgetWithText(ListTile, 'Jam notifikasi');
    expect(tester.getSize(row).height, greaterThanOrEqualTo(48));
    expect(
      tester.getSize(find.byType(SwitchListTile)).height,
      greaterThanOrEqualTo(48),
    );
    sch
      ..notif = PermissionState.denied
      ..notifAfterRequest = PermissionState.denied;
    sch.failAll = true;
    await tester.runAsync(() async {
      await c.setNotify(false);
      await c.setNotify(true);
    });
    await tester.pump();
    expect(tester.takeException(), isNull);
  });

  tw('hadith source change keeps a visible denied note', (tester) async {
    sch.notif = PermissionState.denied;
    sch.notifAfterRequest = PermissionState.denied;
    store.notifyEnabled = true;
    final c = await pump(tester);
    await tester.runAsync(() => c.setNotifyTime('06:30'));
    await tester.pump();
    expect(find.text(_denied), findsOneWidget);
    c.setHadithSource(HadithSource.allBooks);
    await settle(tester);
    expect(find.text(_denied), findsOneWidget);
  });

  tw('time picker: cancel keeps time, OK stores zero-padded HH:mm', (
    tester,
  ) async {
    store
      ..notifyEnabled = true
      ..notifyTime = '07:05';
    await pump(tester);
    await tester.tap(find.text('Jam notifikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(store.notifyTime, '07:05');
    expect(sch.log, isNot(contains('cancelDaily')));
    await tester.tap(find.text('Jam notifikasi'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await settle(tester);
    expect(store.notifyTime, '07:05');
    expect(sch.log, contains('cancelDaily'));
  });
}
