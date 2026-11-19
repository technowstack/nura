import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/daily_content.dart';
import '../../../data/repositories/daily_content_repository.dart';
import '../../../data/repositories/daily_settings_store.dart';
import '../../../services/daily_notifier.dart';
import '../../../services/daily_refresher.dart';
import '../../../services/hijri_date_service.dart';
import '../../../data/repositories/prayer_store.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../widgets/home_hero_data.dart';

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

  // Optional so the daily cards work without them.
  final HijriDateService? _hijri = Get.isRegistered<HijriDateService>()
      ? Get.find<HijriDateService>()
      : null;
  final QuranRepository? _quran = Get.isRegistered<QuranRepository>()
      ? Get.find<QuranRepository>()
      : null;
  final UserRepository? _user = Get.isRegistered<UserRepository>()
      ? Get.find<UserRepository>()
      : null;
  final PrayerStore? _prayerStore = Get.isRegistered<PrayerStore>()
      ? Get.find<PrayerStore>()
      : null;

  late final hero = Rx<HomeHeroData>(_buildHero());
  final lastRead = Rx<LastReadInfo?>(null);

  DateTime now() => _now();

  HomeHeroData _buildHero() {
    final t = _now();
    String region = '';
    try {
      region = _prayerStore?.getLocation()?.kabkota ?? '';
    } on Object catch (e) {
      debugPrint('HomeController: cannot read location: $e');
    }
    return HomeHeroData(
      locationLabel: region.isEmpty ? 'Pilih wilayah' : region,
      hijriDate: _hijri?.format(t) ?? '',
      clock:
          '${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}',
      emptyText: region.isEmpty
          ? 'Pilih wilayah untuk melihat jadwal sholat'
          : 'Jadwal belum tersedia',
    );
  }

  void refreshLastRead() {
    try {
      final ref = _user?.getLastRead()?.ref;
      final s = ref == null ? null : _quran?.getSurah(ref.surah);
      lastRead.value = ref == null || s == null
          ? null
          : LastReadInfo(
              surah: ref.surah,
              ayah: ref.ayah,
              nameArab: s.nameArab,
              nameLatin: s.nameLatin,
            );
    } on Object catch (e) {
      debugPrint('HomeController: last read unavailable: $e');
      lastRead.value = null;
    }
  }

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
    hero.value = _buildHero();
    refreshLastRead();
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
