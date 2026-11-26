import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'notification_scheduler.dart';
import 'daily_notifier.dart';
import 'prayer_notifier.dart';

class FlutterLocalNotificationsScheduler implements NotificationScheduler {
  FlutterLocalNotificationsScheduler([FlutterLocalNotificationsPlugin? plugin])
    : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const channelId = 'prayer_times';
  static const channelName = 'Waktu sholat';
  static const dailyChannelId = 'daily_content';
  static const dailyChannelName = 'Ayat & hadis harian';

  /// Called with the payload when a notification is tapped; wired by the app.
  void Function(String? payload)? onTap;

  final FlutterLocalNotificationsPlugin _plugin;

  AndroidFlutterLocalNotificationsPlugin? get _android => _plugin
      .resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin
      >();

  static PermissionState _state(bool? v) => switch (v) {
    true => PermissionState.granted,
    false => PermissionState.denied,
    null => PermissionState.notRequired,
  };

  Future<void>? _init;

  /// Idempotent; every other call awaits it so early calls cannot race it.
  @override
  Future<void> init() => _init ??= _plugin
      .initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_nura'),
        ),
        onDidReceiveNotificationResponse: (r) => onTap?.call(r.payload),
      )
      .then<void>((_) {})
      .onError<Object>((e, st) {
        _init = null; // a failed init must not be cached; retry next call
        Error.throwWithStackTrace(e, st);
      });

  @override
  Future<void> cancelPrayer() async {
    await init();
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (isPrayerNotificationId(p.id)) await _plugin.cancel(id: p.id);
    }
  }

  @override
  Future<void> cancelDaily() async {
    await init();
    for (final p in await _plugin.pendingNotificationRequests()) {
      if (isDailyNotificationId(p.id)) await _plugin.cancel(id: p.id);
    }
  }

  @override
  Future<void> schedule(
    int id,
    DateTime utcInstant,
    String title,
    String body, {
    required bool exact,
    String? payload,
  }) async {
    await init();
    await _plugin.zonedSchedule(
      id: id,
      // The UTC location is built into package:timezone; no database needed.
      scheduledDate: tz.TZDateTime.from(utcInstant, tz.UTC),
      title: title,
      body: body,
      payload: payload,
      notificationDetails: NotificationDetails(
        android: isDailyNotificationId(id)
            ? AndroidNotificationDetails(
                dailyChannelId,
                dailyChannelName,
                styleInformation: BigTextStyleInformation(body),
              )
            : const AndroidNotificationDetails(
                channelId,
                channelName,
                importance: Importance.high,
                priority: Priority.high,
              ),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }

  @override
  Future<PermissionState> notificationPermission() async {
    await init();
    return _state(await _android?.areNotificationsEnabled());
  }

  @override
  Future<PermissionState> requestNotificationPermission() async {
    await init();
    return _state(await _android?.requestNotificationsPermission());
  }

  @override
  Future<PermissionState> exactAlarmPermission() async {
    await init();
    return _state(await _android?.canScheduleExactNotifications());
  }

  @override
  Future<PermissionState> requestExactAlarmPermission() async {
    await init();
    await _android?.requestExactAlarmsPermission();
    return exactAlarmPermission();
  }
}
