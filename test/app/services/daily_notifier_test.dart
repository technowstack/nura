import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/daily_index.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/services/daily_notifier.dart';
import 'package:nura/app/services/notification_scheduler.dart';
import 'package:nura/app/services/prayer_notifier.dart';

import '../../support/fake_daily.dart';
import '../../support/fake_notifications.dart';

class _Gated extends RecordingScheduler {
  Completer<void> gate = Completer<void>();

  @override
  Future<void> cancelDaily() async {
    log.add('cancel-start');
    await gate.future;
    await super.cancelDaily();
  }
}

// Test code: `!` marks values the fixture guarantees; a null fails the test anyway.
void main() {
  late RecordingScheduler sch;
  late FakeDailyContentRepository repo;
  late FakeDailySettingsStore store;
  late DateTime now;

  DailyNotifier make() => DailyNotifier(
    scheduler: sch,
    repository: repo,
    store: store,
    now: () => now,
  );

  DateTime at(int day, [int h = 6, int m = 0]) => DateTime(2026, 11, day, h, m);

  setUp(() {
    sch = RecordingScheduler();
    repo = FakeDailyContentRepository();
    store = FakeDailySettingsStore()..notifyEnabled = true;
    now = DateTime(2026, 11, 15, 5);
  });

  test('seven days at the configured local time', () async {
    await make().reschedule();
    final got = sch.pending.values.map((s) => s.at).toList();
    expect(got, [for (var d = 15; d < 22; d++) at(d).toUtc()]);
    expect(sch.pending.values.every((s) => s.payload == 'daily'), isTrue);
    expect(sch.pending.values.every((s) => s.exact), isTrue);
  });

  test('past instants are skipped', () async {
    now = DateTime(2026, 11, 15, 7);
    await make().reschedule();
    expect(sch.pending.length, 6);
    expect(sch.pending.containsKey(dailyNotificationId(at(15))), isFalse);
  });

  test('changing the time shifts every instant', () async {
    final n = make();
    await n.reschedule();
    await n.setTime('21:30');
    expect(sch.pending.length, 7);
    expect(
      sch.pending[dailyNotificationId(at(16))]?.at,
      at(16, 21, 30).toUtc(),
    );
  });

  test('disabled cancels and schedules nothing', () async {
    final n = make();
    await n.reschedule();
    await n.setEnabled(false);
    expect(sch.pending, isEmpty);
    expect(sch.log.last, 'cancelDaily');
  });

  test('alternation: even dayIndex ayah, odd hadith, content shape', () async {
    await make().reschedule();
    for (var d = 15; d < 22; d++) {
      final s = sch.pending[dailyNotificationId(at(d))]!;
      final ayah = dayIndex(at(d)) % 2 == 0;
      expect(s.title, ayah ? 'Ayat hari ini' : 'Hadis hari ini');
      expect(s.body, contains('\n'));
      expect(
        s.body,
        contains(ayah ? 'QS. Asy-Syarh: $d' : 'HR. Bukhari No. $d'),
      );
      expect(s.body.runes.any((r) => r >= 0x600 && r <= 0x6FF), isFalse);
      expect(s.title.runes.any((r) => r >= 0x600 && r <= 0x6FF), isFalse);
    }
  });

  test('no ayah list means hadith only', () async {
    repo.withAyah = false;
    await make().reschedule();
    expect(
      sch.pending.values.every((s) => s.title == 'Hadis hari ini'),
      isTrue,
    );
    expect(sch.pending.length, 7);
  });

  test('a null ayah day falls back to the hadith', () async {
    final r = _NullAyah();
    final n = DailyNotifier(
      scheduler: sch,
      repository: r,
      store: store,
      now: () => now,
    );
    await n.reschedule();
    expect(sch.pending.length, 7);
    expect(
      sch.pending.values.every((s) => s.title == 'Hadis hari ini'),
      isTrue,
    );
  });

  test('hadith source feeds the content', () async {
    store.hadithSource = HadithSource.allBooks;
    repo.withAyah = false;
    await make().reschedule();
    expect(sch.pending.values.first.body, contains('(all)'));
  });

  test('ids: k=7, no collision, isolation', () {
    expect(dailyNotificationId(DateTime(2026, 11, 15)), 202611157);
    expect(isDailyNotificationId(202611157), isTrue);
    expect(isPrayerNotificationId(202611157), isFalse);
    for (final k in [0, 1, 2, 3, 4, 9]) {
      expect(isDailyNotificationId(20261115 * 10 + k), isFalse);
      expect(isPrayerNotificationId(20261115 * 10 + k), isTrue);
    }
    expect(isDailyNotificationId(202613457), isFalse);
    expect(isDailyNotificationId(7), isFalse);
    final last = dailyNotificationId(DateTime(2100, 12, 31));
    expect(last, lessThan(1 << 31));
    expect(isDailyNotificationId(last), isTrue);
  });

  test('cancelPrayer and cancelDaily are isolated', () async {
    sch.pending[202611150] = Scheduled(202611150, now, 't', 'b', true, null);
    sch.pending[202611157] = Scheduled(202611157, now, 't', 'b', true, null);
    await sch.cancelPrayer();
    expect(sch.pending.keys, [202611157]);
    sch.pending[202611150] = Scheduled(202611150, now, 't', 'b', true, null);
    await sch.cancelDaily();
    expect(sch.pending.keys, [202611150]);
  });

  test('reschedule twice leaves the same set', () async {
    final n = make();
    await n.reschedule();
    final first = sch.pending.keys.toSet();
    await n.reschedule();
    expect(sch.pending.keys.toSet(), first);
    expect(sch.pending.length, 7);
  });

  test('overlapping reschedules are serialized', () async {
    final g = _Gated();
    final n = DailyNotifier(
      scheduler: g,
      repository: repo,
      store: store,
      now: () => now,
    );
    final a = n.reschedule();
    final b = n.reschedule();
    await Future<void>.delayed(Duration.zero);
    expect(g.log.where((e) => e == 'cancel-start').length, 1);
    g.gate.complete();
    await Future.wait([a, b]);
    expect(g.log.where((e) => e == 'cancel-start').length, 2);
    final firstSchedule = g.log.indexWhere((e) => e.startsWith('schedule'));
    final secondCancel = g.log.lastIndexOf('cancel-start');
    expect(g.log.lastIndexOf('cancelDaily'), greaterThan(firstSchedule));
    expect(secondCancel, greaterThan(firstSchedule));
    expect(g.pending.length, 7);
  });

  test('permission denied: nothing scheduled and switch stays off', () async {
    store.notifyEnabled = false;
    sch.notif = PermissionState.denied;
    sch.notifAfterRequest = PermissionState.denied;
    final ok = await make().setEnabled(true);
    expect(ok, isFalse);
    expect(store.notifyEnabled, isFalse);
    expect(sch.pending, isEmpty);
    expect(sch.log, contains('requestNotif'));
  });

  test('permission granted on request enables and schedules', () async {
    store.notifyEnabled = false;
    sch.notif = PermissionState.denied;
    final ok = await make().setEnabled(true);
    expect(ok, isTrue);
    expect(store.notifyEnabled, isTrue);
    expect(sch.pending.length, 7);
  });

  test('all fail throws, partial failure schedules the rest', () async {
    final t = ThrowingScheduler()..failAll = true;
    final n = DailyNotifier(
      scheduler: t,
      repository: repo,
      store: store,
      now: () => now,
    );
    await expectLater(n.reschedule(), throwsA(isA<DailyScheduleException>()));
    t
      ..failAll = false
      ..failId = dailyNotificationId(at(17));
    await n.reschedule();
    expect(t.pending.length, 6);
  });

  test(
    'toggle on (pending permission) then off ends OFF, nothing scheduled',
    () async {
      store.notifyEnabled = false;
      final g = _GatedPermission()..notif = PermissionState.denied;
      final n = DailyNotifier(
        scheduler: g,
        repository: repo,
        store: store,
        now: () => now,
      );
      final on = n.setEnabled(true);
      final off = n.setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      g.gate.complete(PermissionState.granted);
      await Future.wait([on, off]);
      expect(store.notifyEnabled, isFalse);
      expect(g.pending, isEmpty);
    },
  );

  test('a time that normalizes into the next day keeps ids distinct', () async {
    final n = DailyNotifier(
      scheduler: sch,
      repository: repo,
      store: store,
      now: () => now,
      localAt: (y, m, d, h, mi) => DateTime(y, m, d + 1, 0, 30),
    );
    await n.reschedule();
    expect(sch.pending.length, 7);
    expect(sch.pending.keys.toSet().length, 7);
    expect(sch.pending.containsKey(dailyNotificationId(at(15))), isTrue);
  });

  test('inexact when exact alarms are denied', () async {
    sch.exactState = PermissionState.denied;
    await make().reschedule();
    expect(sch.pending.values.every((s) => !s.exact), isTrue);
  });
}

class _GatedPermission extends RecordingScheduler {
  final gate = Completer<PermissionState>();

  @override
  Future<PermissionState> requestNotificationPermission() => gate.future;
}

class _NullAyah extends FakeDailyContentRepository {
  @override
  DailyContent? ayahFor(DateTime localDate) => null;
}
