import 'dart:async';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/services/flutter_local_notifications_scheduler.dart';

import '../../support/fake_notifications.dart';
import '../../support/prayer_harness.dart';
import '../../support/fake_prayer.dart';
import 'package:nura/app/services/prayer_notifier.dart';

class FakePlugin extends Fake implements FlutterLocalNotificationsPlugin {
  int initCalls = 0;
  bool failFirstInit = false;
  List<int> pendingIds = [];
  final cancelled = <int>[];

  @override
  Future<bool?> initialize({
    required InitializationSettings settings,
    DidReceiveNotificationResponseCallback? onDidReceiveNotificationResponse,
    DidReceiveBackgroundNotificationResponseCallback?
    onDidReceiveBackgroundNotificationResponse,
  }) async {
    initCalls++;
    if (failFirstInit && initCalls == 1) throw StateError('init boom');
    return true;
  }

  @override
  Future<List<PendingNotificationRequest>>
  pendingNotificationRequests() async => [
    for (final i in pendingIds) PendingNotificationRequest(i, null, null, null),
  ];

  @override
  Future<void> cancel({required int id, String? tag}) async =>
      cancelled.add(id);
}

/// cancelPrayer blocks on a completer so overlapping calls can be observed.
class GatedScheduler extends RecordingScheduler {
  Completer<void> gate = Completer<void>();

  @override
  Future<void> cancelPrayer() async {
    log.add('cancel-start');
    await gate.future;
    await super.cancelPrayer();
  }
}

class ThrowingScheduler extends RecordingScheduler {
  int? failId;

  @override
  Future<void> schedule(
    int id,
    DateTime utcInstant,
    String title,
    String body, {
    required bool exact,
  }) async {
    if (id == failId) throw StateError('boom');
    await super.schedule(id, utcInstant, title, body, exact: exact);
  }
}

void main() {
  test('cancelPrayer cancels only ids in the prayer scheme', () async {
    final plugin = FakePlugin()
      ..pendingIds = [1, 202611150, 202611159, 999999999];
    await FlutterLocalNotificationsScheduler(plugin).cancelPrayer();
    expect(plugin.cancelled, [202611150, 202611159]);
  });

  test('a failed init is not cached; the next call retries', () async {
    final plugin = FakePlugin()..failFirstInit = true;
    final s = FlutterLocalNotificationsScheduler(plugin);
    await expectLater(s.init(), throwsStateError);
    await s.init();
    expect(plugin.initCalls, 2);
    await s.init();
    expect(plugin.initCalls, 2);
  });

  test('overlapping reschedule calls never interleave', () async {
    final sched = GatedScheduler();
    final store = MemoryPrayerStore(region: jakarta)..on.add(PrayerName.subuh);
    final repo = FakePrayerRepository(region: jakarta);
    for (final d in ['2026-11-15', '2026-11-16']) {
      store.days[d] = fullDay(d);
      repo.days[d] = DayResult(DayOutcome.api, fullDay(d));
    }
    final n = PrayerNotifier(
      scheduler: sched,
      repository: repo,
      store: store,
      clock: FakeClock(DateTime.utc(2026, 11, 14, 17)),
    );
    final a = n.reschedule();
    final b = n.reschedule();
    await Future<void>.delayed(Duration.zero);
    sched.gate.complete();
    await Future.wait([a, b]);
    final entries = sched.log.where((e) => e != 'cancel-start').toList();
    // cancel, schedule*, cancel, schedule*
    expect(entries.first, 'cancel');
    final second = entries.indexOf('cancel', 1);
    expect(second, greaterThan(1));
    expect(
      entries.sublist(1, second).every((e) => e.startsWith('schedule')),
      isTrue,
    );
    expect(
      entries.sublist(second + 1).every((e) => e.startsWith('schedule')),
      isTrue,
    );
    expect(sched.pending.length, 3); // 2 days + update reminder
  });

  test('one failing schedule does not abort the rest', () async {
    final sched = ThrowingScheduler()
      ..failId = prayerNotificationId('2026-11-16', 0);
    final store = MemoryPrayerStore(region: jakarta)..on.add(PrayerName.subuh);
    final repo = FakePrayerRepository(region: jakarta);
    for (final d in ['2026-11-15', '2026-11-16', '2026-11-17']) {
      store.days[d] = fullDay(d);
      repo.days[d] = DayResult(DayOutcome.api, fullDay(d));
    }
    await PrayerNotifier(
      scheduler: sched,
      repository: repo,
      store: store,
      clock: FakeClock(DateTime.utc(2026, 11, 14, 17)),
    ).reschedule();
    expect(sched.pending.keys.toList()..sort(), [
      prayerNotificationId('2026-11-15', 0),
      prayerNotificationId('2026-11-17', 0),
      prayerNotificationId('2026-11-17', 9),
    ]);
  });
}
