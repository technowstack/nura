import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import '../../../core/errors.dart';
import '../../../core/ui_state.dart';
import '../../../data/models/juz.dart';
import '../../../data/models/surah.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';

class QuranListController extends GetxController {
  final QuranRepository _quran = Get.find();
  final UserRepository _user = Get.find();

  final surahs = Rx<UiState<List<Surah>>>(const UiLoading());
  final juz = Rx<UiState<List<Juz>>>(const UiLoading());
  final bookmarkedSurahs = <int>{}.obs;

  /// 0 means there is no last-read position yet.
  final lastReadSurah = 0.obs;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    surahs.value = const UiLoading();
    juz.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(() {
      surahs.value = _read(_quran.listSurah);
      juz.value = _read(_quran.listJuz);
      refreshMarkers();
    });
  }

  /// Latin names by surah number; empty until the surah list has loaded.
  Map<int, String> get surahNames {
    final state = surahs.value;
    return state is UiData<List<Surah>>
        ? {for (final s in state.value) s.number: s.nameLatin}
        : const {};
  }

  /// 'Al-Fatihah 1 – Al-Baqarah 141'; falls back to the surah number when a
  /// name is unavailable.
  static String juzRange(Juz j, Map<int, String> names) {
    String at(int surah, int ayah) => '${names[surah] ?? 'Surah $surah'} $ayah';
    return '${at(j.startSurah, j.startAyah)} – ${at(j.endSurah, j.endAyah)}';
  }

  /// Re-reads bookmark and last-read markers (e.g. after leaving the surah page).
  void refreshMarkers() {
    try {
      bookmarkedSurahs.assignAll(_user.bookmarkedSurahNumbers());
      lastReadSurah.value = _user.getLastRead()?.ref.surah ?? 0;
    } on Object catch (e) {
      // Markers are decoration; the lists stay usable without them.
      debugPrint('QuranListController: markers unavailable: $e');
    }
  }

  UiState<List<T>> _read<T>(List<T> Function() read) {
    try {
      final rows = read();
      return rows.isEmpty ? const UiEmpty() : UiData(rows);
    } on ContentUnavailable {
      return const UiError('Konten tidak dapat dibaca.');
    }
  }
}
