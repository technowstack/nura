import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/daily_content.dart';
import '../../../data/models/prayer_day.dart';
import '../../../data/models/prayer_region.dart';
import '../../../data/models/prayer_regions.dart';
import '../../../data/repositories/audio_settings_store.dart';
import '../../../data/repositories/daily_settings_store.dart';
import '../../../data/repositories/prayer_repository.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../../../services/audio_player_service.dart';
import '../../../services/daily_notifier.dart';
import '../../../services/daily_refresher.dart';
import '../../../services/hijri_date_service.dart';
import '../../../services/online_service.dart';
import '../../../services/prayer_notifier.dart';
import '../../home/controllers/home_controller.dart';
import '../../prayer/controllers/prayer_controller.dart';
import '../../quran_detail/reading_prefs_mixin.dart';

/// Every user setting on one screen. It owns no settings of its own: each
/// action writes the same store and calls the same live service the old
/// screens did, then re-reads the value so the UI mirrors the real state.
class SettingsController extends GetxController with ReadingPrefsMixin {
  SettingsController({DateTime Function()? now}) : _now = now ?? DateTime.now;

  final DateTime Function() _now;

  final UserRepository _user = Get.find();
  final QuranRepository _quran = Get.find();
  final OnlineService _online = Get.find();
  final AudioSettingsStore _audioStore = Get.find();
  final AudioPlayerService _player = Get.find();
  final PrayerRepository _prayer = Get.find();
  final PrayerNotifier _prayerNotifier = Get.find();
  final DailySettingsStore _daily = Get.find();
  final DailyNotifier _dailyNotifier = Get.find();
  final DailyRefresher _refresher = Get.find();
  final HijriDateService _hijri = Get.find();
  final PrayerRegions regions = Get.find();
  final ThemeController theme = Get.find();

  @override
  UserRepository get userRepository => _user;

  final state = Rx<UiState<void>>(const UiLoading());

  /// First ayah, shown by the live previews; null when it cannot be read.
  final preview = Rxn<({String arab, String translation})>();

  final audioOn = false.obs;
  final qariId = ''.obs;
  final syncOn = false.obs;

  final region = Rxn<PrayerRegion>();
  final notifyOn = <PrayerName, bool>{}.obs;
  final notifyDenied = false.obs;
  final exactDenied = false.obs;
  final remindersFailed = false.obs;

  final hadithSource = HadithSource.defaultBm.obs;
  final dailyOn = false.obs;
  final dailyTime = '06:00'.obs;
  final dailyDenied = false.obs;
  final dailyFailed = false.obs;

  final hijriAdjust = 0.obs;

  /// Today's Hijri date with the current adjustment.
  final hijriExample = ''.obs;

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
        prefs.value = _user.getReadingPrefs();
        audioOn.value = _online.audioEnabled;
        qariId.value = _audioStore.qariId;
        syncOn.value = _online.prayerSyncEnabled;
        region.value = _prayer.region;
        hadithSource.value = _daily.hadithSource;
        dailyOn.value = _daily.notifyEnabled;
        dailyTime.value = _daily.notifyTime;
        _readHijri();
        for (final p in PrayerName.values) {
          notifyOn[p] = _prayerNotifier.isEnabled(p);
        }
        _loadPreview();
        state.value = const UiData<void>(null);
      } on Object catch (e) {
        debugPrint('SettingsController: load failed: $e');
        state.value = const UiError('Pengaturan tidak dapat dimuat.');
        return;
      }
      unawaited(_refreshPrayerNote());
      unawaited(_refreshDailyNote());
    });
  }

  void _loadPreview() {
    try {
      final a = _quran.getAyah(const AyahRef(1, 1));
      preview.value = (arab: a.arab, translation: a.translation);
    } on Object catch (e) {
      debugPrint('SettingsController: preview unavailable: $e');
      preview.value = null;
    }
  }

  void _readHijri() {
    hijriAdjust.value = _hijri.adjustDays;
    hijriExample.value = _hijri.format(_now());
  }

  /// Runs a write; a failure never reaches the UI except as a snackbar.
  bool _try(String what, void Function() write) {
    try {
      write();
      return true;
    } on Object catch (e) {
      debugPrint('SettingsController: $what failed: $e');
      notify('Gagal menyimpan pengaturan');
      return false;
    }
  }

  // Fitur online

  /// Turning it off stops playback: AudioPlayerService listens to
  /// [OnlineService.audioEnabledChanges].
  void setAudioEnabled(bool on) {
    _try('online switch', () => _online.setAudioEnabled(on));
    audioOn.value = _online.audioEnabled;
  }

  void setQari(String id) {
    if (!_try('qari', () => _audioStore.setQariId(id))) return;
    qariId.value = id;
    _player.onQariChanged();
  }

  Future<void> setSyncEnabled(bool on) async {
    _try('sync switch', () => _online.setPrayerSyncEnabled(on));
    syncOn.value = _online.prayerSyncEnabled;
    await _afterPrayerChange();
  }

  // Jadwal sholat

  Future<void> selectRegion(PrayerRegion r) async {
    if (!_try('region', () => _prayer.selectRegion(r))) return;
    region.value = r;
    await _afterPrayerChange();
  }

  Future<void> setNotify(PrayerName p, bool on) async {
    try {
      final ok = await _prayerNotifier.setEnabled(p, on);
      remindersFailed.value = false;
      await _refreshPrayerNote();
      if (!ok) notifyDenied.value = true;
    } on PrayerScheduleException catch (e) {
      remindersFailed.value = true;
      debugPrint('SettingsController: $e');
      await _refreshPrayerNote();
    } on Object catch (e) {
      debugPrint('SettingsController: reminder switch failed: $e');
    }
    if (_alive<PrayerController>()) {
      await Get.find<PrayerController>().refreshReminders();
    }
  }

  /// Like the Sholat tab after a region or sync change: sync the month if the
  /// switch allows it, reschedule the reminders, refresh the notes. When the
  /// tab controller exists its reload() does the sync and reschedule, so it
  /// runs only once.
  Future<void> _afterPrayerChange() async {
    if (_alive<PrayerController>()) {
      unawaited(Get.find<PrayerController>().reload());
      await _refreshPrayerNote();
      return;
    }
    try {
      await _prayer.syncIfNeeded();
    } on Object catch (e) {
      debugPrint('SettingsController: sync failed: $e');
    }
    try {
      await _prayerNotifier.reschedule();
      remindersFailed.value = false;
    } on PrayerScheduleException catch (e) {
      remindersFailed.value = true;
      debugPrint('SettingsController: $e');
    } on Object catch (e) {
      debugPrint('SettingsController: reschedule failed: $e');
    }
    await _refreshPrayerNote();
  }

  Future<void> _refreshPrayerNote() async {
    try {
      for (final p in PrayerName.values) {
        notifyOn[p] = _prayerNotifier.isEnabled(p);
      }
      final st = await _prayerNotifier.status();
      final any = _prayerNotifier.anyEnabled;
      notifyDenied.value = any && st.notificationDenied;
      exactDenied.value = any && !st.notificationDenied && st.exactDenied;
    } on Object catch (e) {
      debugPrint('SettingsController: permission check failed: $e');
    }
  }

  /// A tab controller that exists. A registered but not yet created lazy one
  /// must stay untouched: finding it here would tie it to /settings and
  /// delete it on pop.
  bool _alive<T>() => Get.isRegistered<T>() && !Get.isPrepared<T>();

  @override
  void onClose() {
    // Beranda may be under a reader: it re-reads what Settings changed.
    if (_alive<HomeController>()) {
      Get.find<HomeController>().refreshAfterSettings();
    }
    super.onClose();
  }

  // Harian

  void setHadithSource(HadithSource s) {
    if (!_try('hadith source', () => _daily.setHadithSource(s))) return;
    hadithSource.value = s;
    unawaited(_rescheduleDaily(_dailyNotifier.reschedule));
    // Rewrites the widget images for the new source.
    unawaited(_refresher.refresh(force: true));
  }

  Future<void> setDailyNotify(bool on) async {
    var refused = false;
    await _rescheduleDaily(() async {
      refused = !await _dailyNotifier.setEnabled(on);
    });
    if (refused) dailyDenied.value = true;
  }

  /// [hhmm] is a valid 24h `HH:mm`.
  Future<void> setDailyTime(String hhmm) =>
      _rescheduleDaily(() => _dailyNotifier.setTime(hhmm));

  /// Failures never reach the UI; the switch state is re-read on every path.
  Future<void> _rescheduleDaily(Future<void> Function() action) async {
    try {
      await action();
      dailyFailed.value = false;
    } on DailyScheduleException catch (e) {
      dailyFailed.value = true;
      debugPrint('SettingsController: $e');
    } on Object catch (e) {
      debugPrint('SettingsController: daily notifications failed: $e');
    }
    dailyOn.value = _daily.notifyEnabled;
    dailyTime.value = _daily.notifyTime;
    await _refreshDailyNote();
  }

  Future<void> _refreshDailyNote() async {
    try {
      dailyDenied.value =
          _daily.notifyEnabled && await _dailyNotifier.permissionDenied();
    } on Object catch (e) {
      debugPrint('SettingsController: permission check failed: $e');
    }
  }

  // Tanggal

  void setHijriAdjust(int days) {
    _try('hijri adjustment', () => _hijri.adjustDays = days);
    _readHijri();
  }
}
