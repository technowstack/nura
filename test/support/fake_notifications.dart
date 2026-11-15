import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/repositories/prayer_store.dart';
import 'package:nura/app/services/notification_scheduler.dart';

class Scheduled {
  Scheduled(this.id, this.at, this.title, this.body, this.exact);

  final int id;
  final DateTime at;
  final String title, body;
  final bool exact;
}

class RecordingScheduler implements NotificationScheduler {
  PermissionState notif = PermissionState.granted;
  PermissionState exactState = PermissionState.granted;
  PermissionState notifAfterRequest = PermissionState.granted;
  final pending = <int, Scheduled>{};
  final log = <String>[];

  @override
  Future<void> init() async {}

  @override
  Future<void> cancelPrayer() async {
    log.add('cancel');
    pending.clear();
  }

  @override
  Future<void> schedule(
    int id,
    DateTime utcInstant,
    String title,
    String body, {
    required bool exact,
  }) async {
    log.add('schedule:$id');
    pending[id] = Scheduled(id, utcInstant, title, body, exact);
  }

  @override
  Future<PermissionState> notificationPermission() async => notif;

  @override
  Future<PermissionState> requestNotificationPermission() async {
    log.add('requestNotif');
    return notif = notifAfterRequest;
  }

  @override
  Future<PermissionState> exactAlarmPermission() async => exactState;

  @override
  Future<PermissionState> requestExactAlarmPermission() async {
    log.add('requestExact');
    return exactState;
  }
}

class ThrowingScheduler extends RecordingScheduler {
  int? failId;
  bool failAll = false;
  bool failCancel = false;

  @override
  Future<void> cancelPrayer() async {
    if (failCancel) throw StateError('cancel boom');
    await super.cancelPrayer();
  }

  @override
  Future<void> schedule(
    int id,
    DateTime utcInstant,
    String title,
    String body, {
    required bool exact,
  }) async {
    if (failAll || id == failId) throw StateError('boom');
    await super.schedule(id, utcInstant, title, body, exact: exact);
  }
}

class MemoryPrayerStore implements PrayerStore {
  MemoryPrayerStore({this.region});

  PrayerRegion? region;
  final days = <String, PrayerDay>{};
  final on = <PrayerName>{};

  @override
  PrayerRegion? getLocation() => region;
  @override
  PrayerDay? getDay(String date, PrayerRegion r) => days[date];
  @override
  bool notifyEnabled(PrayerName p) => on.contains(p);
  @override
  void setNotifyEnabled(PrayerName p, bool v) => v ? on.add(p) : on.remove(p);

  @override
  void setLocation(PrayerRegion r, {required String source}) => region = r;
  @override
  void saveMonth(PrayerRegion r, int y, int m, List<PrayerDay> d) {}
  @override
  void markMonthNone(PrayerRegion r, int y, int m, int nowMs) {}
  @override
  MonthRecord? getMonth(PrayerRegion r, int y, int m) => null;
  @override
  void saveCalcDay(PrayerRegion r, PrayerDay d) {}
  @override
  int apiDaysFrom(String date, PrayerRegion r) => 0;
}
