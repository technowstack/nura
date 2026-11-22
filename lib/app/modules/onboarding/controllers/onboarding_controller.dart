import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/prayer_day.dart';
import '../../../data/models/prayer_region.dart';
import '../../../data/models/prayer_regions.dart';
import '../../../data/repositories/daily_settings_store.dart';
import '../../../data/repositories/prayer_repository.dart';
import '../../../data/sources/setting_keys.dart';
import '../../../data/sources/user_database.dart';
import '../../../routes/app_routes.dart';
import '../../../services/daily_notifier.dart';
import '../../../services/online_service.dart';
import '../../../services/prayer_notifier.dart';
import '../../../services/prayer_refresh.dart';

const kOnboardingSteps = 3;

/// First-run flow: welcome, prayer schedule, notifications. It owns no
/// settings: every choice goes to the same stores and services Settings uses,
/// so the two stay in sync. `onboarding_done` is written only by [finish].
class OnboardingController extends GetxController {
  final UserDatabase _user = Get.find();
  final OnlineService _online = Get.find();
  final PrayerRepository _prayer = Get.find();
  final PrayerNotifier _prayerNotifier = Get.find();
  final DailySettingsStore _daily = Get.find();
  final DailyNotifier _dailyNotifier = Get.find();
  final PrayerRegions regions = Get.find();

  final state = Rx<UiState<void>>(const UiLoading());
  final step = 0.obs;

  final region = Rxn<PrayerRegion>();
  final syncOn = false.obs;
  final prayerOn = false.obs;
  final dailyOn = false.obs;
  final dailyTime = '06:00'.obs;
  final denied = false.obs;
  final remindersFailed = false.obs;
  final dailyFailed = false.obs;

  bool get isFirst => step.value == 0;
  bool get isLast => step.value == kOnboardingSteps - 1;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    state.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(() {
      if (isClosed) return;
      try {
        region.value = _prayer.region;
        syncOn.value = _online.prayerSyncEnabled;
        prayerOn.value = PrayerName.values.every(_prayerNotifier.isEnabled);
        dailyOn.value = _daily.notifyEnabled;
        dailyTime.value = _daily.notifyTime;
        state.value = const UiData<void>(null);
      } on Object catch (e) {
        debugPrint('OnboardingController: load failed: $e');
        state.value = const UiError('Setelan tidak dapat dimuat.');
      }
    });
  }

  void next() {
    if (!isLast) step.value++;
  }

  void back() {
    if (!isFirst) step.value--;
  }

  /// "Mulai" and "Lewati" on the last step. A failed write must not trap the
  /// user: they enter the app and see onboarding again next launch.
  void finish() {
    try {
      _user.setSetting(SettingKeys.onboardingDone, 'true');
    } on Object catch (e) {
      debugPrint('OnboardingController: could not save completion: $e');
    }
    Get.offAllNamed<void>(Routes.home);
  }

  // Jadwal sholat

  Future<void> selectRegion(PrayerRegion r) async {
    try {
      _prayer.selectRegion(r);
    } on Object catch (e) {
      debugPrint('OnboardingController: region failed: $e');
      return;
    }
    region.value = r;
    remindersFailed.value = await syncAndReschedule(_prayer, _prayerNotifier);
  }

  /// The first moment anything online can happen.
  Future<void> setSyncEnabled(bool on) async {
    try {
      _online.setPrayerSyncEnabled(on);
    } on Object catch (e) {
      debugPrint('OnboardingController: sync switch failed: $e');
    }
    syncOn.value = _online.prayerSyncEnabled;
    remindersFailed.value = await syncAndReschedule(_prayer, _prayerNotifier);
  }

  // Notifikasi

  /// All five prayer reminders on or off. The permission is requested by the
  /// first one turned on; a refusal leaves the switch off.
  Future<void> setPrayerReminders(bool on) async {
    denied.value = false;
    try {
      for (final p in PrayerName.values) {
        if (!await _prayerNotifier.setEnabled(p, on)) {
          denied.value = true;
          break;
        }
      }
      remindersFailed.value = false;
    } on PrayerScheduleException catch (e) {
      remindersFailed.value = true;
      debugPrint('OnboardingController: $e');
    } on Object catch (e) {
      debugPrint('OnboardingController: reminders failed: $e');
    }
    prayerOn.value = PrayerName.values.every(_prayerNotifier.isEnabled);
  }

  Future<void> setDailyNotify(bool on) async {
    denied.value = false;
    try {
      if (!await _dailyNotifier.setEnabled(on)) denied.value = true;
      dailyFailed.value = false;
    } on DailyScheduleException catch (e) {
      dailyFailed.value = true;
      debugPrint('OnboardingController: $e');
    } on Object catch (e) {
      debugPrint('OnboardingController: daily failed: $e');
    }
    dailyOn.value = _daily.notifyEnabled;
    dailyTime.value = _daily.notifyTime;
  }
}
