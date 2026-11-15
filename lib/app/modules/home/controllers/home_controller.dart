import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/daily_content.dart';
import '../../../data/repositories/daily_content_repository.dart';
import '../../../data/repositories/daily_settings_store.dart';
import '../../../services/daily_notifier.dart';
import '../../../services/daily_refresher.dart';

/// Today's cards; at least one of them is non-null.
class DailyCards {
  const DailyCards({this.ayah, this.hadith});

  final DailyContent? ayah;
  final DailyContent? hadith;
}

class HomeController extends GetxController with WidgetsBindingObserver {
  HomeController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;
  final DailyContentRepository _repo = Get.find();
  final DailySettingsStore _settings = Get.find();

  final DailyNotifier? _notifier = Get.isRegistered<DailyNotifier>()
      ? Get.find<DailyNotifier>()
      : null;

  final DailyRefresher? _refresher = Get.isRegistered<DailyRefresher>()
      ? Get.find<DailyRefresher>()
      : null;

  final cards = Rx<UiState<DailyCards>>(const UiLoading());
  late final hadithSource = Rx<HadithSource>(_settings.hadithSource);

  late final notifyOn = Rx<bool>(_settings.notifyEnabled);
  late final notifyTime = Rx<String>(_settings.notifyTime);

  /// The notification permission was refused when turning the switch on.
  final notifyDenied = false.obs;

  /// Every daily notification failed to schedule.
  final notifyFailed = false.obs;

  Timer? _midnight;

  @override
  void onInit() {
    super.onInit();
    WidgetsBinding.instance.addObserver(this);
    refreshForToday();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    _midnight?.cancel();
    super.onClose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) refreshForToday();
  }

  void setHadithSource(HadithSource s) {
    try {
      _settings.setHadithSource(s);
      hadithSource.value = s;
    } on Object catch (e) {
      debugPrint('HomeController: cannot save hadith source: $e');
    }
    refreshForToday();
    unawaited(_reschedule(() => _notifier?.reschedule()));
    // Rewrites the widget images for the new source.
    unawaited(_refresher?.refresh(force: true));
  }

  Future<void> setNotify(bool on) async {
    var refused = false;
    await _reschedule(() async {
      refused = !(await _notifier?.setEnabled(on) ?? true);
    });
    if (refused) notifyDenied.value = true;
  }

  /// [hhmm] is a valid 24h `HH:mm`.
  Future<void> setNotifyTime(String hhmm) =>
      _reschedule(() => _notifier?.setTime(hhmm));

  /// Failures never reach the UI; the switch state is re-read on every path.
  Future<void> _reschedule(Future<void>? Function() action) async {
    try {
      await action();
      notifyFailed.value = false;
    } on DailyScheduleException catch (e) {
      notifyFailed.value = true;
      debugPrint('HomeController: $e');
    } on Object catch (e) {
      debugPrint('HomeController: daily notifications failed: $e');
    }
    notifyOn.value = _settings.notifyEnabled;
    notifyTime.value = _settings.notifyTime;
    // The note mirrors the real permission, so other changes keep it.
    try {
      notifyDenied.value =
          _settings.notifyEnabled &&
          (await _notifier?.permissionDenied() ?? false);
    } on Object catch (e) {
      debugPrint('HomeController: permission check failed: $e');
    }
  }

  void refreshForToday() {
    final day = _now();
    try {
      final ayah = _repo.ayahFor(day);
      final hadith = _repo.hadithFor(day, hadithSource.value);
      cards.value = ayah == null && hadith == null
          ? const UiEmpty()
          : UiData(DailyCards(ayah: ayah, hadith: hadith));
    } on Object catch (e) {
      debugPrint('HomeController: daily content unavailable: $e');
      cards.value = const UiError('Konten harian tidak dapat dibaca.');
    }
    _armMidnight(day);
  }

  /// One-shot timer to the next local midnight; re-armed by the refresh it
  /// triggers.
  void _armMidnight(DateTime day) {
    _midnight?.cancel();
    final next = DateTime(day.year, day.month, day.day + 1);
    _midnight = Timer(next.difference(day), () {
      refreshForToday();
      unawaited(_refresher?.refresh());
    });
  }
}
