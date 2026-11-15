import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/services/notification_scheduler.dart';
import 'package:nura/app/services/prayer_notifier.dart';

import '../../support/fake_notifications.dart';
import '../../support/fake_prayer.dart';
import '../../support/prayer_harness.dart';

String ymd(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class Rig {
  Rig({required DateTime now, required int dayCount, region = jakarta})
    : store = MemoryPrayerStore(region: region),
      clock = FakeClock(now) {
    repo = FakePrayerRepository(region: region);
    final start = DateTime.utc(2026, 11, 15);
    for (var i = 0; i < dayCount; i++) {
      final date = ymd(start.add(Duration(days: i)));
      store.days[date] = fullDay(date);
      repo.days[date] = DayResult(DayOutcome.api, fullDay(date));
    }
    notifier = PrayerNotifier(
      scheduler: sched,
      repository: repo,
      store: store,
      clock: clock,
    );
  }

  final sched = RecordingScheduler();
  final MemoryPrayerStore store;
  final FakeClock clock;
  late final FakePrayerRepository repo;
  late final PrayerNotifier notifier;

  List<int> get ids => sched.pending.keys.toList()..sort();
}

// 2026-11-15 00:00 WIB.
final midnight = DateTime.utc(2026, 11, 14, 17);

void main() {
  test('reschedule twice gives the same set without duplicates', () async {
    final r = Rig(now: midnight, dayCount: 5)
      ..store.on.addAll(PrayerName.values);
    await r.notifier.reschedule();
    final first = r.ids;
    await r.notifier.reschedule();
    expect(r.ids, first);
    expect(r.sched.log.where((e) => e == 'cancel').length, 2);
    // 5 days x 5 prayers + 1 update reminder.
    expect(first.length, 26);
  });

  test('only enabled prayers are scheduled', () async {
    final r = Rig(now: midnight, dayCount: 2)
      ..store.on.addAll([PrayerName.subuh, PrayerName.isya]);
    await r.notifier.reschedule();
    expect(r.ids.where((i) => i % 10 <= 4).map((i) => i % 10).toSet(), {0, 4});
    expect(
      r.sched.pending[prayerNotificationId('2026-11-15', 0)]?.title,
      'Waktu Subuh',
    );
    expect(
      r.sched.pending[prayerNotificationId('2026-11-15', 0)]?.body,
      'Pukul 04:30 WIB · Kota Jakarta',
    );
  });

  test('past times are skipped', () async {
    // 12:00 WIB: subuh and dzuhur (11:50) are past.
    final r = Rig(now: DateTime.utc(2026, 11, 15, 5), dayCount: 1)
      ..store.on.addAll(PrayerName.values);
    await r.notifier.reschedule();
    expect(r.ids.map((i) => i % 10).toList()..sort(), [2, 3, 4]);
  });

  test('61 days of data stop at day 30, no update reminder', () async {
    final r = Rig(now: midnight, dayCount: 61)..store.on.add(PrayerName.subuh);
    await r.notifier.reschedule();
    expect(r.ids.length, 30);
    expect(r.ids.last, prayerNotificationId('2026-12-14', 0));
    expect(r.ids.any((i) => i % 10 == 9), isFalse);
  });

  test('exactly 30 days of data: reminder on day 30', () async {
    final r = Rig(now: midnight, dayCount: 30)..store.on.add(PrayerName.subuh);
    await r.notifier.reschedule();
    expect(r.ids.length, 31);
    expect(r.ids.contains(prayerNotificationId('2026-12-14', 9)), isTrue);
  });

  test(
    '10 days of data stop at day 10 with one update reminder at 08:00',
    () async {
      final r = Rig(now: midnight, dayCount: 10)
        ..store.on.add(PrayerName.subuh);
      await r.notifier.reschedule();
      await r.notifier.reschedule();
      expect(r.ids.length, 11);
      final u = r.sched.pending[prayerNotificationId('2026-11-24', 9)];
      expect(u?.at, DateTime.utc(2026, 11, 24, 1)); // 08:00 WIB
      expect(u?.body, 'Buka Nura untuk memperbarui jadwal sholat.');
      expect(r.ids.where((i) => i % 10 == 9).length, 1);
    },
  );

  test(
    'no update reminder when all switches are off or already past',
    () async {
      final off = Rig(now: midnight, dayCount: 10);
      await off.notifier.reschedule();
      expect(off.ids, isEmpty);
      // After 08:00 on the last stored day.
      final late = Rig(now: DateTime.utc(2026, 11, 24, 2), dayCount: 10)
        ..store.on.add(PrayerName.isya);
      await late.notifier.reschedule();
      expect(late.ids.any((i) => i % 10 == 9), isFalse);
    },
  );

  test('WIT region on a WIB device uses the region offset', () async {
    final r = Rig(now: midnight, dayCount: 1, region: jayapura)
      ..store.on.add(PrayerName.subuh);
    await r.notifier.reschedule();
    final s = r.sched.pending[prayerNotificationId('2026-11-15', 0)];
    expect(s?.at, DateTime.utc(2026, 11, 14, 19, 30)); // 04:30 WIT
    expect(s?.body, 'Pukul 04:30 WIT · Kota Jayapura');
  });

  test('notification permission denied: cancel only', () async {
    final r = Rig(now: midnight, dayCount: 3)..store.on.add(PrayerName.subuh);
    r.sched.notif = PermissionState.denied;
    await r.notifier.reschedule();
    expect(r.ids, isEmpty);
    expect(r.sched.log, ['cancel']);
  });

  test('exact alarm denied: every item is inexact', () async {
    final r = Rig(now: midnight, dayCount: 3)..store.on.add(PrayerName.subuh);
    r.sched.exactState = PermissionState.denied;
    await r.notifier.reschedule();
    expect(r.sched.pending.values.every((s) => !s.exact), isTrue);
    expect(r.sched.pending, isNotEmpty);
  });

  test('switch and region changes cancel then reschedule', () async {
    final r = Rig(now: midnight, dayCount: 2)..store.on.add(PrayerName.subuh);
    await r.notifier.reschedule();
    expect(await r.notifier.setEnabled(PrayerName.isya, true), isTrue);
    expect(r.ids.map((i) => i % 10).toSet(), {0, 4, 9});
    r.sched.log.clear();
    r.store.region = jayapura;
    r.repo.region = jayapura;
    await r.notifier.reschedule();
    expect(r.sched.log.first, 'cancel');
    expect(
      r.sched.pending[prayerNotificationId('2026-11-15', 0)]?.at,
      DateTime.utc(2026, 11, 14, 19, 30),
    );
  });

  test('turning on with permission denied keeps the switch off', () async {
    final r = Rig(now: midnight, dayCount: 2);
    r.sched
      ..notif = PermissionState.denied
      ..notifAfterRequest = PermissionState.denied;
    expect(await r.notifier.setEnabled(PrayerName.subuh, true), isFalse);
    expect(r.store.on, isEmpty);
    expect(r.sched.log, contains('requestNotif'));
  });

  test('first switch requests exact alarm permission when denied', () async {
    final r = Rig(now: midnight, dayCount: 2);
    r.sched.exactState = PermissionState.denied;
    await r.notifier.setEnabled(PrayerName.subuh, true);
    expect(r.sched.log, contains('requestExact'));
  });

  test('unknown region and no region cancel everything', () async {
    final r = Rig(now: midnight, dayCount: 3)..store.on.add(PrayerName.subuh);
    await r.notifier.reschedule();
    expect(r.ids, isNotEmpty);
    r.repo.days['2026-11-15'] = const DayResult(DayOutcome.unknownRegion);
    await r.notifier.reschedule();
    expect(r.ids, isEmpty);
    r.repo.region = null;
    await r.notifier.reschedule();
    expect(r.ids, isEmpty);
  });

  test('id scheme fits 32 bits and is recognised', () {
    final id = prayerNotificationId('2100-12-31', 9);
    expect(id, 210012319);
    expect(id < 0x7fffffff, isTrue);
    expect(isPrayerNotificationId(id), isTrue);
    expect(isPrayerNotificationId(5), isFalse);
    expect(
      isPrayerNotificationId(prayerNotificationId('2026-11-15', 5)),
      isFalse,
    );
  });
}
