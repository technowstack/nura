import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/ui_state.dart';
import '../../../data/models/ayah.dart';
import '../../../data/models/reading_prefs.dart';
import '../../../data/models/surah.dart';
import '../../../data/repositories/quran_repository.dart';
import '../../../data/repositories/user_repository.dart';
import '../surah_args.dart';

class SurahContent {
  const SurahContent({
    required this.surah,
    required this.basmalah,
    required this.ayahs,
  });

  final Surah surah;
  final String basmalah;
  final List<Ayah> ayahs;
}

class QuranDetailController extends GetxController {
  QuranDetailController(this.args);

  final SurahArgs args;
  final QuranRepository _quran = Get.find();
  final UserRepository _user = Get.find();

  final state = Rx<UiState<SurahContent>>(const UiLoading());
  final bookmarked = <int>{}.obs;
  late final prefs = Rx<ReadingPrefs>(_user.getReadingPrefs());
  final ListController listController = ListController();

  @override
  void onInit() {
    super.onInit();
    load();
  }

  void load() {
    state.value = const UiLoading();
    // Deferred so the loading state is rendered before the data.
    Future.microtask(() {
      try {
        final ayahs = _quran.listAyah(args.surah);
        if (ayahs.isEmpty) {
          state.value = const UiEmpty();
          return;
        }
        final content = SurahContent(
          surah: _quran.getSurah(args.surah),
          basmalah: _quran.getAyah(const AyahRef(1, 1)).arab,
          ayahs: ayahs,
        );
        final marks = _user.bookmarkedAyahNumbers(args.surah);
        final readingPrefs = _user.getReadingPrefs();
        bookmarked.assignAll(marks);
        prefs.value = readingPrefs;
        state.value = UiData(content);
      } on Object catch (e) {
        debugPrint('QuranDetailController: load failed: $e');
        state.value = const UiError('Konten tidak dapat dibaca.');
      }
    });
  }

  void toggleBookmark(int ayahNumber) {
    try {
      final on = _user.toggleBookmark(AyahRef(args.surah, ayahNumber));
      if (on) {
        bookmarked.add(ayahNumber);
      } else {
        bookmarked.remove(ayahNumber);
      }
    } on Object catch (e) {
      debugPrint('QuranDetailController: bookmark failed: $e');
      _notify('Gagal menyimpan bookmark');
    }
  }

  Future<void> copyAyah(Ayah ayah) async {
    final current = state.value;
    if (current is! UiData<SurahContent>) return;
    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${ayah.arab}\n\n${ayah.translation}\n\nQS. ${current.value.surah.nameLatin}: ${ayah.ayahNumber}',
        ),
      );
      _notify('Ayat disalin');
    } on Object catch (e) {
      debugPrint('QuranDetailController: copy failed: $e');
      _notify('Gagal menyalin ayat');
    }
  }

  void _notify(String message) => Get.showSnackbar(
    GetSnackBar(message: message, duration: const Duration(seconds: 2)),
  );
}
