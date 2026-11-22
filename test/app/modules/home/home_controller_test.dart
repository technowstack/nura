import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/errors.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/repositories/daily_content_repository.dart';
import 'package:nura/app/data/repositories/daily_settings_store.dart';
import 'package:nura/app/modules/home/controllers/home_controller.dart';
import 'package:nura/app/services/daily_refresher.dart';

import '../../../support/fake_daily.dart';
import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart' show jakarta, makassar, api;

void main() {
  late FakeDailyContentRepository repo;
  late FakeDailySettingsStore store;
  late DateTime clock;

  setUp(() {
    Get.reset();
    repo = FakeDailyContentRepository();
    store = FakeDailySettingsStore();
    clock = DateTime(2026, 11, 15, 10);
    Get.put<DailyContentRepository>(repo);
    Get.put<DailySettingsStore>(store);
  });
  tearDown(Get.reset);

  // Closes the controller (cancelling its timer) before the framework checks
  // for pending timers.
  void tc(String name, Future<void> Function(WidgetTester) body) =>
      testWidgets(name, (tester) async {
        await body(tester);
        Get.delete<HomeController>(force: true);
      });

  HomeController make() =>
      Get.put(HomeController(now: () => clock), permanent: false);

  DailyCards cards(HomeController c) =>
      (c.cards.value as UiData<DailyCards>).value;

  tc('ayah null shows only the hadith', (tester) async {
    repo.withAyah = false;
    final c = make();
    expect(cards(c).ayah, isNull);
    expect(cards(c).hadith?.reference, 'HR. Bukhari No. 15');
  });

  tc('both present: ayah and hadith of today', (tester) async {
    final c = make();
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 15');
    expect(cards(c).hadith?.translation, contains('(default)'));
  });

  tc('both null is empty', (tester) async {
    repo.withAyah = false;
    repo.withHadith = false;
    expect(make().cards.value, isA<UiEmpty<DailyCards>>());
  });

  tc('failure is UiError and retry recovers', (tester) async {
    repo.failure = const ContentUnavailable('x');
    final c = make();
    expect(c.cards.value, isA<UiError<DailyCards>>());
    repo.failure = null;
    c.refreshForToday();
    expect(c.cards.value, isA<UiData<DailyCards>>());
  });

  tc('crossing local midnight switches the cards and re-arms', (tester) async {
    final c = make();
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 15');
    clock = DateTime(2026, 11, 16);
    await tester.pump(const Duration(hours: 14));
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 16');
    clock = DateTime(2026, 11, 17);
    await tester.pump(const Duration(hours: 24));
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 17');
  });

  tc('refreshAfterSettings picks up a source changed in Settings', (
    tester,
  ) async {
    final c = make();
    expect(cards(c).hadith?.translation, contains('(default)'));
    store.setHadithSource(HadithSource.allBooks); // what Settings does
    c.refreshAfterSettings();
    expect(c.hadithSource.value, HadithSource.allBooks);
    expect(cards(c).hadith?.translation, contains('(all)'));
  });

  tc('resume refreshes', (tester) async {
    final c = make();
    final before = repo.calls;
    clock = DateTime(2026, 11, 16, 8);
    c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(repo.calls, before + 1);
    expect(cards(c).ayah?.reference, 'QS. Asy-Syarh: 16');
  });

  group('daily refresher', () {
    late int renders;

    // Built inside the test body so its futures live in the fake-async zone.
    void putRefresher() {
      renders = 0;
      Get.put(
        DailyRefresher(
          renderWidgets: () async {
            renders++;
            return true;
          },
          reschedule: () async {},
          now: () => clock,
        ),
      );
    }

    tc('crossing midnight refreshes once for the new date', (tester) async {
      await tester.pumpWidget(const SizedBox());
      putRefresher();
      make();
      unawaited(Get.find<DailyRefresher>().refresh());
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      clock = DateTime(2026, 11, 16);
      await tester.pump(const Duration(hours: 14));
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 1));
      expect(renders, 2);
    });
  });

  group('prayer hero', () {
    late FakePrayerRepository prayer;

    setUp(() {
      // Jakarta is WIB (+7): 10:33Z is 17:33 local.
      clock = DateTime.utc(2026, 11, 19, 10, 33).toLocal();
      prayer = FakePrayerRepository(
        region: jakarta,
        days: {
          '2026-11-19': api('2026-11-19'),
          '2026-11-20': api('2026-11-20'),
        },
      );
      Get.put<PrayerRepository>(prayer);
    });

    tc('shows real times and the countdown', (tester) async {
      final c = make();
      await tester.pump();
      final h = c.hero.value;
      expect(h.locationLabel, 'Kota Jakarta');
      expect(h.times, hasLength(6));
      expect(h.countdownText, 'Maghrib dalam 27 menit');
      expect(h.clock, '17:33');
    });

    tc('makes no sync call, only day reads', (tester) async {
      make();
      await tester.pump();
      expect(prayer.calls, ['day:2026-11-19']);
    });

    tc('the hero and clock update when the minute ticks', (tester) async {
      final c = make();
      await tester.pump();
      clock = DateTime.utc(2026, 11, 19, 10, 34).toLocal();
      await tester.pump(const Duration(seconds: 60));
      expect(c.hero.value.clock, '17:34');
      expect(c.hero.value.countdownText, 'Maghrib dalam 26 menit');
    });

    tc('after Isya tomorrow is read for the Subuh countdown', (tester) async {
      clock = DateTime.utc(2026, 11, 19, 14).toLocal(); // 21:00 local
      final c = make();
      await tester.pump();
      expect(prayer.calls, ['day:2026-11-19', 'day:2026-11-20']);
      expect(c.hero.value.countdownText, 'Subuh dalam 7 jam 30 menit');
    });

    tc('the next day reloads at midnight', (tester) async {
      clock = DateTime.utc(
        2026,
        11,
        19,
        16,
        59,
        30,
      ).toLocal(); // 23:59:30 local
      final c = make();
      await tester.pump();
      prayer.calls.clear();
      clock = DateTime.utc(2026, 11, 19, 17).toLocal(); // 00:00 local, 20 Nov
      await tester.pump(const Duration(seconds: 30));
      await tester.pump();
      expect(prayer.calls, contains('day:2026-11-20'));
      expect(c.hero.value.nextIndex, 0);
    });

    tc('resume reloads', (tester) async {
      make();
      await tester.pump();
      prayer.calls.clear();
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(prayer.calls, ['day:2026-11-19']);
    });

    tc('closing cancels the timer', (tester) async {
      make();
      await tester.pump();
      Get.delete<HomeController>(force: true);
      prayer.calls.clear();
      await tester.pump(const Duration(minutes: 5));
      expect(prayer.calls, isEmpty);
    });

    tc('a failing repository leaves the honest empty hero', (tester) async {
      prayer.failWith = StateError('boom');
      final c = make();
      await tester.pump();
      expect(c.hero.value.times, isEmpty);
      expect(c.hero.value.emptyText, 'Jadwal belum tersedia');
    });

    // Plain testWidgets: the framework itself fails on a leaked timer.
    testWidgets('onClose leaves no pending timer', (tester) async {
      make();
      await tester.pump();
      Get.delete<HomeController>(force: true);
    });

    tc('an empty tomorrow is not retried every minute', (tester) async {
      prayer.days.remove('2026-11-20');
      clock = DateTime.utc(2026, 11, 19, 14).toLocal(); // 21:00 local
      make();
      await tester.pump();
      expect(prayer.calls.where((c) => c == 'day:2026-11-20'), hasLength(1));
      for (var i = 0; i < 3; i++) {
        clock = clock.add(const Duration(minutes: 1));
        await tester.pump(const Duration(seconds: 60));
      }
      expect(prayer.calls.where((c) => c == 'day:2026-11-20'), hasLength(1));
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(prayer.calls.where((c) => c == 'day:2026-11-20'), hasLength(2));
    });

    tc('a region change refreshes the hero on the next tick', (tester) async {
      final c = make();
      await tester.pump();
      expect(c.hero.value.locationLabel, 'Kota Jakarta');
      prayer.region = makassar;
      clock = clock.add(const Duration(minutes: 1));
      await tester.pump(const Duration(seconds: 60));
      await tester.pump();
      expect(c.hero.value.locationLabel, 'Kota Makassar');
    });

    tc('out-of-order prayer loads keep the latest result', (tester) async {
      final slow = _Pending(region: jakarta);
      Get.delete<PrayerRepository>(force: true);
      Get.put<PrayerRepository>(slow);
      final c = make(); // load 1
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(slow.pending, hasLength(2)); // load 2
      slow.pending[1].complete(DayResult(DayOutcome.api, _day('18:00')));
      await tester.pump();
      slow.pending[0].complete(
        DayResult(DayOutcome.api, _day('18:30')),
      ); // stale, finishes last
      await tester.pump();
      expect(c.hero.value.times.map((t) => t.time), contains('18:00'));
      expect(c.hero.value.times.map((t) => t.time), isNot(contains('18:30')));
    });

    tc('resume after a region change drops the old region times', (
      tester,
    ) async {
      final slow = _Pending(region: jakarta);
      Get.delete<PrayerRepository>(force: true);
      Get.put<PrayerRepository>(slow);
      final c = make();
      slow.pending[0].complete(DayResult(DayOutcome.api, _day('18:00')));
      await tester.pump();
      expect(c.hero.value.times, isNotEmpty);
      slow.region = makassar;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      expect(c.hero.value.locationLabel, 'Kota Makassar');
      expect(c.hero.value.times, isEmpty, reason: 'no stale Jakarta times');
    });

    tc('pausing cancels the minute and midnight timers', (tester) async {
      make();
      await tester.pump();
      prayer.calls.clear();
      final before = repo.calls;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump(const Duration(hours: 30));
      expect(prayer.calls, isEmpty);
      expect(repo.calls, before, reason: 'midnight refresh is cancelled');
    });
  });
}

PrayerDay _day(String maghrib) => PrayerDay(
  date: '2026-11-19',
  subuh: '04:30',
  dzuhur: '11:50',
  ashar: '15:10',
  maghrib: maghrib,
  isya: '19:10',
  source: PrayerSource.api,
  fetchedAt: 1,
);

/// Answers each `dayFor` with a completer the test finishes by hand.
class _Pending extends FakePrayerRepository {
  _Pending({super.region});

  final pending = <Completer<DayResult>>[];

  Future<DayResult> _next() {
    final c = Completer<DayResult>();
    pending.add(c);
    return c.future;
  }

  @override
  Future<DayResult> dayFor(String date) => _next();
}
