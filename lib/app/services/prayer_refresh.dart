import 'package:flutter/foundation.dart';

import '../data/repositories/prayer_repository.dart';
import 'prayer_notifier.dart';

/// After a region or sync-switch change: sync the month (the repository
/// no-ops unless the switch is on and reachable), then reschedule reminders.
/// Returns true when the reminders could not be scheduled. Never throws.
Future<bool> syncAndReschedule(
  PrayerRepository repository,
  PrayerNotifier notifier,
) async {
  try {
    await repository.syncIfNeeded();
  } on Object catch (e) {
    debugPrint('syncAndReschedule: sync failed: $e');
  }
  try {
    await notifier.reschedule();
    return false;
  } on PrayerScheduleException catch (e) {
    debugPrint('syncAndReschedule: $e');
    return true;
  } on Object catch (e) {
    debugPrint('syncAndReschedule: reschedule failed: $e');
    return false;
  }
}
