import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/errors.dart';
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
        state.value = UiData(
          SurahContent(
            surah: _quran.getSurah(args.surah),
            basmalah: _quran.getAyah(const AyahRef(1, 1)).arab,
            ayahs: ayahs,
          ),
        );
        bookmarked.assignAll(_user.bookmarkedAyahNumbers(args.surah));
        prefs.value = _user.getReadingPrefs();
      } on ContentUnavailable {
        state.value = const UiError('Konten tidak dapat dibaca.');
      }
    });
  }

  void toggleBookmark(int ayahNumber) {
    final on = _user.toggleBookmark(AyahRef(args.surah, ayahNumber));
    if (on) {
      bookmarked.add(ayahNumber);
    } else {
      bookmarked.remove(ayahNumber);
    }
  }

  Future<void> copyAyah(Ayah ayah) async {
    final surah = switch (state.value) {
      UiData(:final value) => value.surah.nameLatin,
      _ => _quran.getSurah(ayah.surahNumber).nameLatin,
    };
    await Clipboard.setData(
      ClipboardData(
        text:
            '${ayah.arab}\n\n${ayah.translation}\n\nQS. $surah: ${ayah.ayahNumber}',
      ),
    );
    Get.showSnackbar(
      const GetSnackBar(
        message: 'Ayat disalin',
        duration: Duration(seconds: 2),
      ),
    );
  }
}
