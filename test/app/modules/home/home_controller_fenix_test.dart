import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';

import '../../../support/fake_daily.dart';
import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart' show jakarta, api;

/// Counts region reads: each minute tick reads it twice per live timer.
class _CountingPrayer extends FakePrayerRepository {
  _CountingPrayer() : super(region: jakarta);

  int reads = 0;

  @override
  PrayerRegion? get region {
    reads++;
    return super.region;
  }
}

void main() {
  late FakeDailyContentRepository repo;
  late _CountingPrayer prayer;
  late DateTime clock;

  setUp(() {
    Get.reset();
    repo = FakeDailyContentRepository();
    clock = DateTime.utc(2026, 11, 19, 3, 0).toLocal();
    prayer = _CountingPrayer();
    prayer.days['2026-11-19'] = api('2026-11-19');
    Get.put<DailyContentRepository>(repo);
    Get.put<DailySettingsStore>(FakeDailySettingsStore());
    Get.put<PrayerRepository>(prayer);
    // The shell's binding, as in production: recreated on demand.
    Get.lazyPut<HomeController>(
      () => HomeController(now: () => clock),
      fenix: true,
    );
  });
  tearDown(Get.reset);

  // Closes live controllers before the framework checks for pending timers.
  void tc(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (t) async {
        await body(t);
        Get.delete<HomeController>(force: true);
      });

  void lifecycle(WidgetTester t, AppLifecycleState s) =>
      t.binding.handleAppLifecycleStateChanged(s);

  // Reads of the region during one minute tick, and ayah reads over one
  // midnight; both are per live instance.
  Future<({int ticks, int midnights})> work(WidgetTester t) async {
    await t.pump();
    var r = prayer.reads;
    var a = repo.calls;
    await t.pump(const Duration(minutes: 1));
    final ticks = prayer.reads - r;
    r = prayer.reads;
    a = repo.calls;
    await t.pump(const Duration(hours: 24));
    return (ticks: ticks, midnights: repo.calls - a);
  }

  tc('deleted instance goes silent: timers and observer', (t) async {
    final old = Get.find<HomeController>();
    await t.pump();
    Get.delete<HomeController>(force: true);
    final reads = prayer.reads;
    final ayahs = repo.calls;
    final dayCalls = prayer.calls.length;
    await t.pump(const Duration(hours: 30));
    lifecycle(t, AppLifecycleState.resumed);
    lifecycle(t, AppLifecycleState.paused);
    expect(prayer.reads, reads, reason: 'no minute tick after onClose');
    expect(repo.calls, ayahs, reason: 'no midnight or resume work');
    expect(prayer.calls.length, dayCalls, reason: 'no repository calls');
    expect(old.isClosed, isTrue);
  });

  tc('fenix instance has one minute and one midnight timer', (t) async {
    Get.find<HomeController>();
    await t.pump();
    Get.delete<HomeController>(force: true);
    final fresh = Get.find<HomeController>();
    final w = await work(t);
    // One live timer reads the region twice per tick (tick + hero build).
    expect(w.ticks, 2);
    expect(w.midnights, 1);
    expect(fresh.isClosed, isFalse);
  });

  tc('with a deleted and a live instance only the new one works', (t) async {
    final old = Get.find<HomeController>();
    await t.pump();
    Get.delete<HomeController>(force: true);
    final fresh = Get.find<HomeController>();
    expect(identical(old, fresh), isFalse);
    clock = DateTime.utc(2026, 11, 19, 3, 1).toLocal();
    final oldHero = old.hero.value;
    await t.pump(const Duration(minutes: 1));
    expect(fresh.hero.value.clock, isNot(oldHero.clock));
    expect(old.hero.value, same(oldHero), reason: 'old hero is frozen');
  });

  tc('resume and pause cause exactly one reload each', (t) async {
    Get.find<HomeController>();
    Get.delete<HomeController>(force: true);
    Get.find<HomeController>();
    await t.pump();
    var a = repo.calls;
    var d = prayer.calls.length;
    lifecycle(t, AppLifecycleState.resumed);
    await t.pump();
    expect(repo.calls - a, 1, reason: 'one daily refresh');
    expect(prayer.calls.length - d, 1, reason: 'one prayer reload');
    a = repo.calls;
    d = prayer.calls.length;
    lifecycle(t, AppLifecycleState.paused);
    await t.pump(const Duration(hours: 30));
    expect(repo.calls, a);
    expect(prayer.calls.length, d);
  });

  tc('closing twice or deleting a deleted controller is safe', (t) async {
    final c = Get.find<HomeController>();
    await t.pump();
    Get.delete<HomeController>(force: true);
    expect(c.onClose, returnsNormally);
    expect(() => Get.delete<HomeController>(force: true), returnsNormally);
    await t.pump(const Duration(hours: 30));
  });
}
