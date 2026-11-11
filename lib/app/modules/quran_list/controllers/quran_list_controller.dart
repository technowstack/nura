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
      try {
        bookmarkedSurahs.assignAll(_user.bookmarkedSurahNumbers());
        lastReadSurah.value = _user.getLastRead()?.ref.surah ?? 0;
      } on ContentUnavailable {
        // Markers are decoration; the lists stay usable without them.
      }
    });
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
