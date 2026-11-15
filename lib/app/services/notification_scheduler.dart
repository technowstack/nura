enum PermissionState { granted, denied, notRequired }

/// Thin seam over the local-notifications plugin so the logic is testable.
abstract interface class NotificationScheduler {
  Future<void> init();

  /// Cancels only prayer notifications (ids in the prayer id space).
  Future<void> cancelPrayer();

  Future<void> schedule(
    int id,
    DateTime utcInstant,
    String title,
    String body, {
    required bool exact,
  });

  Future<PermissionState> notificationPermission();
  Future<PermissionState> requestNotificationPermission();
  Future<PermissionState> exactAlarmPermission();
  Future<PermissionState> requestExactAlarmPermission();
}
