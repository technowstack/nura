import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/prayer_clock.dart';
import '../data/models/prayer_day.dart';
import '../data/models/prayer_region.dart';
import '../data/repositories/prayer_repository.dart';
import '../data/repositories/prayer_store.dart';
import 'notification_scheduler.dart';

/// Today (region zone) counts as day 1: the window is today..today+29.
const kMaxScheduleDays = 30;

const updateReminderBody = 'Buka Nura untuk memperbarui jadwal sholat.';
const updateReminderTitle = 'Jadwal sholat';

/// Id = yyyymmdd * 10 + k; k 0..4 = prayers, 9 = update reminder.
/// Fits in 32 bits up to year 2147.
int prayerNotificationId(String date, int k) =>
    int.parse(date.replaceAll('-', '')) * 10 + k;

/// True for ids made by [prayerNotificationId] (dates 2000..2999).
bool isPrayerNotificationId(int id) {
  final k = id % 10;
  final ymd = id ~/ 10;
  return (k <= 4 || k == 9) && ymd >= 20000101 && ymd <= 29991231;
}

String? prayerTimeOf(PrayerDay d, PrayerName p) => switch (p) {
  PrayerName.subuh => d.subuh,
  PrayerName.dzuhur => d.dzuhur,
  PrayerName.ashar => d.ashar,
  PrayerName.maghrib => d.maghrib,
  PrayerName.isya => d.isya,
};

String _label(PrayerName p) => switch (p) {
  PrayerName.subuh => 'Subuh',
  PrayerName.dzuhur => 'Dzuhur',
  PrayerName.ashar => 'Ashar',
  PrayerName.maghrib => 'Maghrib',
  PrayerName.isya => 'Isya',
};

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-'
    '${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

class PrayerPermissionStatus {
  const PrayerPermissionStatus({
    required this.notificationDenied,
    required this.exactDenied,
  });

  final bool notificationDenied;
  final bool exactDenied;
}

/// Every schedule() call of one run failed (a systematic failure).
class PrayerScheduleException implements Exception {
  const PrayerScheduleException(this.count, this.firstError);

  final int count;
  final Object firstError;

  @override
  String toString() => 'PrayerScheduleException: $count failed: $firstError';
}

/// Rebuilds the prayer notifications from the cached times.
class PrayerNotifier {
  PrayerNotifier({
    required NotificationScheduler scheduler,
    required PrayerRepository repository,
    required PrayerStore store,
    required PrayerClock clock,
  }) : _scheduler = scheduler,
       _repo = repository,
       _store = store,
       _clock = clock;

  final NotificationScheduler _scheduler;
  final PrayerRepository _repo;
  final PrayerStore _store;
  final PrayerClock _clock;

  Future<void> _tail = Future<void>.value();

  bool isEnabled(PrayerName p) => _store.notifyEnabled(p);
  bool get anyEnabled => PrayerName.values.any(isEnabled);

  Future<PrayerPermissionStatus> status() async => PrayerPermissionStatus(
    notificationDenied:
        await _scheduler.notificationPermission() == PermissionState.denied,
    exactDenied:
        await _scheduler.exactAlarmPermission() == PermissionState.denied,
  );

  /// Returns false (and leaves the switch off) when turning on is refused
  /// because the notification permission was denied.
  Future<bool> setEnabled(PrayerName p, bool on) async {
    if (on) {
      if (!anyEnabled) {
        if (await _scheduler.notificationPermission() ==
            PermissionState.denied) {
          final r = await _scheduler.requestNotificationPermission();
          if (r == PermissionState.denied) return false;
        }
        if (await _scheduler.exactAlarmPermission() == PermissionState.denied) {
          await _scheduler.requestExactAlarmPermission();
        }
      } else if (await _scheduler.notificationPermission() ==
          PermissionState.denied) {
        return false;
      }
    }
    _store.setNotifyEnabled(p, on);
    await reschedule();
    return true;
  }

  /// Cancels every prayer notification, then schedules the full set again.
  /// Calls are serialized so overlapping triggers cannot interleave.
  Future<void> reschedule() {
    final run = _tail.then((_) => _run());
    _tail = run.catchError((Object e) {
      debugPrint('PrayerNotifier: reschedule failed: $e');
    });
    return run;
  }

  int _attempted = 0;
  int _failed = 0;
  Object? _firstError;

  Future<void> _run() async {
    _attempted = 0;
    _failed = 0;
    _firstError = null;
    await _scheduler.cancelPrayer();
    await _build();
    final first = _firstError;
    if (_attempted > 0 && _failed == _attempted && first != null) {
      throw PrayerScheduleException(_failed, first);
    }
  }

  Future<void> _build() async {
    final region = _repo.region;
    if (region == null) return;
    if (await _scheduler.notificationPermission() == PermissionState.denied) {
      return;
    }
    final enabled = PrayerName.values.where(isEnabled).toList();
    if (enabled.isEmpty) return;
    final exact =
        await _scheduler.exactAlarmPermission() != PermissionState.denied;
    final now = _clock.nowUtc();
    final zone = region.zone;
    final today = _clock.todayIn(zone);
    final t = today.split('-').map(int.parse).toList();
    final start = DateTime.utc(t[0], t[1], t[2]);

    var last = '';
    var ended = false;
    for (var i = 0; i < kMaxScheduleDays; i++) {
      final date = _ymd(start.add(Duration(days: i)));
      final PrayerDay? day;
      if (i == 0) {
        final r = await _repo.dayFor(date);
        if (r.outcome == DayOutcome.unknownRegion ||
            r.outcome == DayOutcome.noRegion) {
          return;
        }
        day = r.day;
      } else {
        day = _store.getDay(date, region);
      }
      if (day == null) {
        ended = true;
        break;
      }
      last = date;
      await _scheduleDay(day, region, enabled, now, exact);
    }
    if (last.isEmpty) return;
    // The last stored day only gets the reminder when it is inside the window
    // (data ended before day 30, or exactly on day 30).
    if (!ended) {
      final beyond = _ymd(start.add(const Duration(days: kMaxScheduleDays)));
      if (_store.getDay(beyond, region) != null) return;
    }
    final at = _clock.instantOf(last, '08:00', zone);
    if (at.isAfter(now)) {
      await _safely(
        () => _scheduler.schedule(
          prayerNotificationId(last, 9),
          at,
          updateReminderTitle,
          updateReminderBody,
          exact: exact,
        ),
      );
    }
  }

  /// One failing item must not abort the rest of the window.
  Future<void> _safely(Future<void> Function() f) async {
    _attempted++;
    try {
      await f();
    } on Object catch (e) {
      _failed++;
      _firstError ??= e;
      debugPrint('PrayerNotifier: schedule failed: $e');
    }
  }

  Future<void> _scheduleDay(
    PrayerDay day,
    PrayerRegion region,
    List<PrayerName> enabled,
    DateTime now,
    bool exact,
  ) async {
    for (final p in enabled) {
      final hhmm = prayerTimeOf(day, p);
      if (hhmm == null) continue;
      final at = _clock.instantOf(day.date, hhmm, region.zone);
      if (!at.isAfter(now)) continue;
      await _safely(
        () => _scheduler.schedule(
          prayerNotificationId(day.date, p.index),
          at,
          'Waktu ${_label(p)}',
          'Pukul $hhmm ${region.zone.label}',
          exact: exact,
        ),
      );
    }
  }
}
