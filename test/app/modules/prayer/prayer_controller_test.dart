import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/ui_state.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/modules/prayer/controllers/prayer_controller.dart';
import 'package:nura/app/modules/shell/controllers/shell_controller.dart';

import '../../../support/fake_prayer.dart';
import '../../../support/prayer_harness.dart';

void main() {
  tp('next prayer is the first one after now', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1), // 08:00 WIB
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.screen.next, PrayerName.dzuhur);
    expect(h.screen.nextAt, DateTime.utc(2026, 11, 15, 4, 50));
    expect(h.screen.nextIsTomorrow, isFalse);
    expect(h.c.countdown.value, '03:50:00');
  });

  tp('before subuh the next prayer is subuh', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 14, 20), // 03:00 WIB
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.screen.next, PrayerName.subuh);
  });

  tp('after isya the next is tomorrow subuh via the repository', (
    tester,
  ) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 13), // 20:00 WIB
      days: {'2026-11-15': api('2026-11-15'), '2026-11-16': api('2026-11-16')},
    );
    await tester.pump();
    expect(h.repo.calls, contains('day:2026-11-16'));
    expect(h.screen.next, PrayerName.subuh);
    expect(h.screen.nextIsTomorrow, isTrue);
    expect(h.screen.nextAt, DateTime.utc(2026, 11, 15, 21, 30));
    expect(h.c.countdown.value, '08:30:00');
  });

  tp('tomorrow unavailable: no countdown, flagged', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 13),
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.screen.next, isNull);
    expect(h.screen.tomorrowMissing, isTrue);
    expect(h.c.countdown.value, '');
  });

  tp('today follows the region zone (WITA past midnight)', (tester) async {
    final h = setup(
      tester,
      region: makassar,
      now: DateTime.utc(2026, 11, 15, 16, 30), // 2026-11-16 00:30 WITA
      days: {'2026-11-16': api('2026-11-16')},
    );
    await tester.pump();
    expect(h.repo.calls, contains('day:2026-11-16'));
    expect(h.screen.next, PrayerName.subuh);
    expect(h.screen.zoneLabel, 'WITA');
    expect(h.screen.nextAt, DateTime.utc(2026, 11, 15, 20, 30));
  });

  tp('WIT region uses its own offset for the instant', (tester) async {
    final h = setup(
      tester,
      region: jayapura,
      now: DateTime.utc(2026, 11, 15, 10), // 19:00 WIT
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.screen.zoneLabel, 'WIT');
    expect(h.screen.next, PrayerName.isya);
    expect(h.screen.nextAt, DateTime.utc(2026, 11, 15, 10, 10));
    expect(h.c.countdown.value, '00:10:00');
  });

  tp('perkiraan only for calc', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {
        '2026-11-15': DayResult(
          DayOutcome.calc,
          fullDay('2026-11-15', source: PrayerSource.calc),
        ),
      },
    );
    await tester.pump();
    expect(h.screen.estimated, isTrue);
    h.repo.days['2026-11-15'] = api('2026-11-15');
    await h.c.reload();
    expect(h.screen.estimated, isFalse);
  });

  tp('outcomes without times keep the outcome and no countdown', (
    tester,
  ) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': const DayResult(DayOutcome.needsInternet)},
    );
    await tester.pump();
    expect(h.screen.outcome, DayOutcome.needsInternet);
    expect(h.screen.hasTimes, isFalse);
    expect(h.c.countdown.value, '');
  });

  tp('no region gives the empty state', (tester) async {
    final h = setup(tester, region: null, now: DateTime.utc(2026, 11, 15, 1));
    await tester.pump();
    expect(h.c.screen.value, isA<UiEmpty<PrayerScreen>>());
  });

  tp('repository failure gives the error state', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
    );
    h.repo.failWith = StateError('boom');
    await h.c.reload();
    expect(h.c.screen.value, isA<UiError<PrayerScreen>>());
  });

  tp('onInit syncs before loading', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.repo.calls.first, 'sync');
    expect(h.repo.calls[1], startsWith('day:'));
  });

  tp('selectRegion and setSyncEnabled sync then reload', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': api('2026-11-15'), '2026-11-16': api('2026-11-16')},
    );
    await tester.pump();
    h.repo.calls.clear();
    await h.c.selectRegion(makassar);
    expect(h.repo.calls.take(2), ['select:${makassar.key}', 'sync']);
    expect(h.repo.calls, contains(startsWith('day:')));
    h.repo.calls.clear();
    await h.c.setSyncEnabled(true);
    expect(h.db.getSetting(SettingKeys.prayerSyncEnabled), 'true');
    expect(h.repo.calls.first, 'sync');
    expect(h.repo.calls, contains(startsWith('day:')));
  });

  tp('countdown ticks from absolute instants', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.c.countdown.value, '03:50:00');
    h.clock.now = h.clock.now.add(const Duration(seconds: 61));
    await tester.pump(const Duration(seconds: 1));
    expect(h.c.countdown.value, '03:48:59');
  });

  tp('countdown rolls to the following prayer', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 4, 49, 59),
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    expect(h.screen.next, PrayerName.dzuhur);
    h.clock.now = DateTime.utc(2026, 11, 15, 4, 50, 1);
    await tester.pump(const Duration(seconds: 1));
    await tester.pump();
    expect(h.screen.next, PrayerName.ashar);
  });

  tp('timer runs only while the Sholat tab is selected', (tester) async {
    final shell = ShellController();
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': api('2026-11-15')},
      shell: shell,
    );
    await tester.pump();
    expect(h.c.countdown.value, '', reason: 'tab 0 is selected');
    expect(tester.binding.hasScheduledFrame, isFalse);
    shell.select(ShellController.prayerTab);
    await tester.pump();
    expect(h.c.countdown.value, '03:50:00');
    shell.select(0);
    await tester.pump();
    h.clock.now = h.clock.now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(h.c.countdown.value, '03:50:00', reason: 'stopped on tab leave');
  });

  tp('timer stops when the app goes to background', (tester) async {
    final h = setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    h.c.didChangeAppLifecycleState(AppLifecycleState.paused);
    h.clock.now = h.clock.now.add(const Duration(minutes: 5));
    await tester.pump(const Duration(seconds: 2));
    expect(h.c.countdown.value, '03:50:00');
    h.repo.calls.clear();
    h.c.didChangeAppLifecycleState(AppLifecycleState.resumed);
    await tester.pump();
    expect(h.repo.calls.first, 'sync');
    expect(h.c.countdown.value, '03:45:00');
  });

  tp('closing the controller cancels the timer', (tester) async {
    setup(
      tester,
      region: jakarta,
      now: DateTime.utc(2026, 11, 15, 1),
      days: {'2026-11-15': api('2026-11-15')},
    );
    await tester.pump();
    Get.delete<PrayerController>(force: true);
  });
}
