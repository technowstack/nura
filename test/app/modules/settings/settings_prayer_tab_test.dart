import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/modules/prayer/controllers/prayer_controller.dart';
import 'package:nura/app/modules/settings/controllers/settings_controller.dart';

import '../../../support/prayer_harness.dart' show jakarta, makassar;
import '../../../support/settings_harness.dart';

/// Settings and the Sholat tab share one state (stores and services).
void main() {
  late SettingsHarness h;

  setUp(() => h = SettingsHarness.create());

  Future<void> settle(WidgetTester t) => pumpSettled(t);

  void closeAll() {
    Get.delete<PrayerController>(force: true);
    Get.delete<SettingsController>(force: true);
  }

  testWidgets('a region chosen in Settings shows on the Sholat tab', (t) async {
    final c = h.controller();
    final tab = Get.put(PrayerController());
    await settle(t);
    expect(tab.screen.value, isA<UiEmpty<PrayerScreen>>());
    unawaited(c.selectRegion(jakarta));
    await settle(t);
    await settle(t);
    final s = tab.screen.value;
    expect(s, isA<UiData<PrayerScreen>>());
    expect((s as UiData<PrayerScreen>).value.region, jakarta);
    closeAll();
  });

  testWidgets('region and reminder set on the Sholat tab show in Settings', (
    t,
  ) async {
    final tab = Get.put(PrayerController());
    unawaited(tab.selectRegion(makassar));
    await settle(t);
    unawaited(tab.setNotify(PrayerName.isya, true));
    await settle(t);
    await settle(t);
    final c = h.controller();
    await settle(t);
    expect(c.region.value, makassar);
    expect(c.notifyOn[PrayerName.isya], isTrue);
    closeAll();
  });

  testWidgets('a reminder toggled in Settings shows on the Sholat tab', (
    t,
  ) async {
    final c = h.controller();
    final tab = Get.put(PrayerController());
    await settle(t);
    unawaited(c.setNotify(PrayerName.maghrib, true));
    await settle(t);
    await settle(t);
    expect(tab.notifyOn[PrayerName.maghrib], isTrue);
    closeAll();
  });

  testWidgets('the sync switch flipped in Settings reaches the repository', (
    t,
  ) async {
    final c = h.controller();
    final tab = Get.put(PrayerController());
    await settle(t);
    unawaited(c.setSyncEnabled(true));
    await settle(t);
    await settle(t);
    expect(h.online.prayerSyncEnabled, isTrue);
    // The tab re-synced (it reads the same OnlineService).
    expect(h.prayer.calls.where((e) => e == 'sync').length, greaterThan(1));
    closeAll();
    expect(tab.isClosed, isTrue);
  });

  testWidgets('with the tab alive, sync and reschedule run once per change', (
    t,
  ) async {
    final c = h.controller();
    Get.put(PrayerController());
    await settle(t);
    h.prayer.calls.clear();
    h.scheduler.log.clear();
    unawaited(c.setSyncEnabled(true));
    await settle(t);
    expect(h.prayer.calls.where((e) => e == 'sync'), hasLength(1));
    expect(h.scheduler.log.where((e) => e == 'cancel'), hasLength(1));
    h.prayer.calls.clear();
    h.scheduler.log.clear();
    unawaited(c.selectRegion(jakarta));
    await settle(t);
    expect(h.prayer.calls.where((e) => e == 'sync'), hasLength(1));
    expect(h.scheduler.log.where((e) => e == 'cancel'), hasLength(1));
    closeAll();
  });

  testWidgets('without the tab, Settings syncs and reschedules itself', (
    t,
  ) async {
    final c = h.controller();
    await settle(t);
    unawaited(c.selectRegion(jakarta));
    await settle(t);
    expect(h.prayer.calls.where((e) => e == 'sync'), hasLength(1));
    expect(h.scheduler.log.where((e) => e == 'cancel'), hasLength(1));
    closeAll();
  });

  testWidgets('a registered but not created tab controller stays untouched', (
    t,
  ) async {
    Get.lazyPut<PrayerController>(PrayerController.new);
    final c = h.controller();
    await settle(t);
    unawaited(c.selectRegion(jakarta));
    await settle(t);
    expect(Get.isPrepared<PrayerController>(), isTrue);
    expect(h.prayer.calls.where((e) => e == 'sync'), hasLength(1));
    closeAll();
  });
}
