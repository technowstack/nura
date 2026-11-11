import 'package:get/get.dart';

import '../controllers/quran_detail_controller.dart';
import '../surah_args.dart';

class QuranDetailBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    // Invalid sentinel: load() shows an error instead of a wrong surah.
    final surahArgs = args is SurahArgs ? args : const SurahArgs(0);
    Get.lazyPut<QuranDetailController>(() => QuranDetailController(surahArgs));
  }
}
