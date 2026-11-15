import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/daily_index.dart';
import '../data/models/daily_content.dart';
import '../data/repositories/daily_content_repository.dart';
import '../data/repositories/daily_settings_store.dart';
import 'notification_scheduler.dart';

/// Today (device local date) counts as day 1: the window is today..today+6.
const kDailyScheduleDays = 7;

/// Payload carried by daily notifications; tapping opens Beranda.
const dailyPayload = 'daily';

/// Id = yyyymmdd * 10 + 7; never collides with prayer ids (k 0..4, 9).
int dailyNotificationId(DateTime d) =>
    (d.year * 10000 + d.month * 100 + d.day) * 10 + 7;

/// True for ids made by [dailyNotificationId] (valid dates 2000..2999).
bool isDailyNotificationId(int id) {
  if (id % 10 != 7) return false;
  final ymd = id ~/ 10;
  if (ymd < 20000101 || ymd > 29991231) return false;
  final y = ymd ~/ 10000, m = ymd ~/ 100 % 100, d = ymd % 100;
  final c = DateTime.utc(y, m, d);
  return c.year == y && c.month == m && c.day == d;
}

/// Every schedule() call of one run failed (a systematic failure).
class DailyScheduleException implements Exception {
  const DailyScheduleException(this.count, this.firstError);

  final int count;
  final Object firstError;

  @override
  String toString() => 'DailyScheduleException: $count failed: $firstError';
}

/// Schedules one notification per day (device local zone) for a week.
class DailyNotifier {
  DailyNotifier({
    required NotificationScheduler scheduler,
    required DailyContentRepository repository,
    required DailySettingsStore store,
    DateTime Function()? now,
  }) : _scheduler = scheduler,
       _repo = repository,
       _store = store,
       _now = now ?? DateTime.now;

  final NotificationScheduler _scheduler;
  final DailyContentRepository _repo;
  final DailySettingsStore _store;
  final DateTime Function() _now;

  Future<void> _tail = Future<void>.value();

  bool get isEnabled => _store.notifyEnabled;

  Future<bool> permissionDenied() async =>
      await _scheduler.notificationPermission() == PermissionState.denied;

  /// Returns false (switch stays off) when the permission was refused.
  Future<bool> setEnabled(bool on) async {
    if (on && await permissionDenied()) {
      final r = await _scheduler.requestNotificationPermission();
      if (r == PermissionState.denied) return false;
    }
    _store.setNotifyEnabled(on);
    await reschedule();
    return true;
  }

  /// [hhmm] must be a valid `HH:mm` (the store throws otherwise).
  Future<void> setTime(String hhmm) {
    _store.setNotifyTime(hhmm);
    return reschedule();
  }

  /// Cancels every daily notification, then schedules the window again.
  /// Calls are serialized so overlapping triggers cannot interleave.
  Future<void> reschedule() {
    final run = _tail.then((_) => _run());
    _tail = run.catchError((Object e) {
      debugPrint('DailyNotifier: reschedule failed: $e');
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
    await _scheduler.cancelDaily();
    await _build();
    final first = _firstError;
    if (_attempted > 0 && _failed == _attempted && first != null) {
      throw DailyScheduleException(_failed, first);
    }
  }

  Future<void> _build() async {
    if (!_store.notifyEnabled) return;
    if (await permissionDenied()) return;
    final exact =
        await _scheduler.exactAlarmPermission() != PermissionState.denied;
    final parts = _store.notifyTime.split(':').map(int.parse).toList();
    final now = _now();
    for (var i = 0; i < kDailyScheduleDays; i++) {
      final at = DateTime(now.year, now.month, now.day + i, parts[0], parts[1]);
      if (!at.toUtc().isAfter(now.toUtc())) continue;
      _attempted++;
      try {
        final c = _contentFor(at);
        if (c == null) {
          _attempted--;
          continue;
        }
        await _scheduler.schedule(
          dailyNotificationId(at),
          at.toUtc(),
          c.kind == DailyKind.ayah ? 'Ayat hari ini' : 'Hadis hari ini',
          '${c.translation}\n${c.reference}',
          exact: exact,
          payload: dailyPayload,
        );
      } on Object catch (e) {
        _failed++;
        _firstError ??= e;
        debugPrint('DailyNotifier: schedule failed: $e');
      }
    }
  }

  /// Even dayIndex => ayah, odd => hadith; falls back to the hadith.
  DailyContent? _contentFor(DateTime day) {
    if (_repo.hasAyah && dayIndex(day) % 2 == 0) {
      final a = _repo.ayahFor(day);
      if (a != null) return a;
    }
    return _repo.hadithFor(day, _store.hadithSource);
  }
}
