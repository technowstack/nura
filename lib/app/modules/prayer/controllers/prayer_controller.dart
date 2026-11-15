import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/prayer_clock.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/prayer_day.dart';
import '../../../data/models/prayer_region.dart';
import '../../../data/models/prayer_regions.dart';
import '../../../data/repositories/prayer_repository.dart';
import '../../../services/online_service.dart';
import '../../../services/prayer_notifier.dart';
import '../../shell/controllers/shell_controller.dart';

/// Everything the Sholat tab shows, already resolved for display.
class PrayerScreen {
  const PrayerScreen({
    required this.outcome,
    required this.region,
    required this.syncEnabled,
    this.day,
    this.next,
    this.nextAt,
    this.nextIsTomorrow = false,
    this.tomorrowMissing = false,
  });

  final DayOutcome outcome;
  final PrayerRegion region;
  final bool syncEnabled;
  final PrayerDay? day;
  final PrayerName? next;

  /// Absolute UTC instant of [next].
  final DateTime? nextAt;
  final bool nextIsTomorrow;
  final bool tomorrowMissing;

  bool get hasTimes => day != null;

  /// Times come from the offline calculation, not from the API.
  bool get estimated => outcome == DayOutcome.calc;

  String get regionLabel => '${region.kabkota}, ${region.provinsi}';
  String get zoneLabel => region.zone.label;
}

class PrayerController extends GetxController with WidgetsBindingObserver {
  PrayerController({ShellController? shell})
    : _shell =
          shell ??
          (Get.isRegistered<ShellController>()
              ? Get.find<ShellController>()
              : null);

  final PrayerRepository _repo = Get.find();
  final PrayerClock _clock = Get.find();
  final OnlineService _online = Get.find();
  final PrayerRegions regions = Get.find();
  final ShellController? _shell;

  /// Null in contexts that do not wire notifications (some tests).
  final PrayerNotifier? _notifier = Get.isRegistered<PrayerNotifier>()
      ? Get.find<PrayerNotifier>()
      : null;

  /// Which reminder switches are on.
  final notifyOn = <PrayerName, bool>{}.obs;

  /// The notification permission is denied (a turn-on was refused or the
  /// permission was revoked while reminders are on).
  final notifyDenied = false.obs;

  /// Exact alarms are denied while reminders are on.
  final exactDenied = false.obs;

  final screen = Rx<UiState<PrayerScreen>>(const UiLoading());

  /// `HH:MM:SS` until the next prayer; empty when there is none.
  final countdown = ''.obs;

  Timer? _timer;
  bool _foreground = true;
  Worker? _tabWorker;

  bool get _tabSelected =>
      _shell == null || _shell.tab.value == ShellController.prayerTab;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    _tabWorker = _shell == null ? null : ever(_shell.tab, (_) => _syncTimer());
    reload();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _tabWorker?.dispose();
    _timer?.cancel();
    _timer = null;
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncTimer();
    if (_foreground) reload();
  }

  /// Syncs when needed, then reloads (screen open, resume, retry).
  Future<void> reload() async {
    try {
      await _repo.syncIfNeeded();
    } on Object catch (e) {
      debugPrint('PrayerController: sync failed: $e');
    }
    await _load();
    await _notify();
  }

  /// Reschedules from the cache, then refreshes the switches and notes.
  Future<void> _notify() async {
    final n = _notifier;
    if (n == null) return;
    try {
      await n.reschedule();
      await _refreshNotify(n);
    } on Object catch (e) {
      debugPrint('PrayerController: notifications failed: $e');
    }
  }

  Future<void> _refreshNotify(PrayerNotifier n) async {
    for (final p in PrayerName.values) {
      notifyOn[p] = n.isEnabled(p);
    }
    final st = await n.status();
    final any = n.anyEnabled;
    notifyDenied.value = any && st.notificationDenied;
    exactDenied.value = any && !st.notificationDenied && st.exactDenied;
  }

  Future<void> setNotify(PrayerName p, bool v) async {
    final n = _notifier;
    if (n == null) return;
    try {
      final ok = await n.setEnabled(p, v);
      await _refreshNotify(n);
      if (!ok) notifyDenied.value = true;
    } on Object catch (e) {
      debugPrint('PrayerController: switch failed: $e');
    }
  }

  Future<void> selectRegion(PrayerRegion r) async {
    _repo.selectRegion(r);
    await reload();
  }

  Future<void> setSyncEnabled(bool v) async {
    _online.setPrayerSyncEnabled(v);
    await reload();
  }

  Future<void> _load() async {
    try {
      final region = _repo.region;
      if (region == null) {
        screen.value = const UiEmpty();
        _syncTimer();
        return;
      }
      final today = _clock.todayIn(region.zone);
      final result = await _repo.dayFor(today);
      final day = result.day;
      final usable =
          day != null &&
          (result.outcome == DayOutcome.api ||
              result.outcome == DayOutcome.calc);
      if (!usable) {
        screen.value = UiData(
          PrayerScreen(
            outcome: result.outcome,
            region: region,
            syncEnabled: _repo.syncEnabled,
          ),
        );
        _syncTimer();
        return;
      }
      final now = _clock.nowUtc();
      var next = _nextToday(day, region.zone, now);
      var tomorrow = false;
      var missing = false;
      if (next == null) {
        tomorrow = true;
        next = await _nextTomorrow(today, region);
        missing = next == null;
      }
      screen.value = UiData(
        PrayerScreen(
          outcome: result.outcome,
          region: region,
          syncEnabled: _repo.syncEnabled,
          day: day,
          next: next?.$1,
          nextAt: next?.$2,
          nextIsTomorrow: tomorrow && !missing,
          tomorrowMissing: missing,
        ),
      );
      _syncTimer();
    } on Object catch (e) {
      debugPrint('PrayerController: schedule unavailable: $e');
      screen.value = const UiError('Jadwal sholat tidak dapat dimuat.');
      _syncTimer();
    }
  }

  static String? _timeOf(PrayerDay d, PrayerName p) => switch (p) {
    PrayerName.subuh => d.subuh,
    PrayerName.dzuhur => d.dzuhur,
    PrayerName.ashar => d.ashar,
    PrayerName.maghrib => d.maghrib,
    PrayerName.isya => d.isya,
  };

  (PrayerName, DateTime)? _nextToday(
    PrayerDay day,
    PrayerZone zone,
    DateTime now,
  ) {
    for (final p in PrayerName.values) {
      final t = _timeOf(day, p);
      if (t == null) continue;
      final at = _clock.instantOf(day.date, t, zone);
      if (at.isAfter(now)) return (p, at);
    }
    return null;
  }

  Future<(PrayerName, DateTime)?> _nextTomorrow(
    String today,
    PrayerRegion region,
  ) async {
    final p = today.split('-').map(int.parse).toList();
    final d = DateTime.utc(p[0], p[1], p[2]).add(const Duration(days: 1));
    final date =
        '${d.year.toString().padLeft(4, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-'
        '${d.day.toString().padLeft(2, '0')}';
    final r = await _repo.dayFor(date);
    final subuh = r.day?.subuh;
    final ok = r.outcome == DayOutcome.api || r.outcome == DayOutcome.calc;
    if (!ok || subuh == null) return null;
    return (PrayerName.subuh, _clock.instantOf(date, subuh, region.zone));
  }

  void _syncTimer() {
    final s = screen.value;
    final at = s is UiData<PrayerScreen> ? s.value.nextAt : null;
    final run = at != null && _tabSelected && _foreground;
    if (!run) {
      _timer?.cancel();
      _timer = null;
      return;
    }
    _tick(at);
    _timer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      final cur = screen.value;
      final target = cur is UiData<PrayerScreen> ? cur.value.nextAt : null;
      if (target != null) _tick(target);
    });
  }

  void _tick(DateTime at) {
    final left = at.difference(_clock.nowUtc());
    if (left <= Duration.zero) {
      // The prayer time passed: pick the following one.
      countdown.value = '';
      _timer?.cancel();
      _timer = null;
      unawaited(_load());
      return;
    }
    countdown.value = formatCountdown(left);
  }
}

String formatCountdown(Duration d) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${two(d.inHours)}:${two(d.inMinutes % 60)}:${two(d.inSeconds % 60)}';
}
