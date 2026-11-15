import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/daily_content.dart';
import '../../../data/repositories/daily_content_repository.dart';
import '../../../data/repositories/daily_settings_store.dart';

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

  final cards = Rx<UiState<DailyCards>>(const UiLoading());
  late final hadithSource = Rx<HadithSource>(_settings.hadithSource);

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
    _midnight = Timer(next.difference(day), refreshForToday);
  }
}
