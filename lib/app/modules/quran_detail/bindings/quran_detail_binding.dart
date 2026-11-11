import 'package:get/get.dart';

import '../controllers/quran_detail_controller.dart';
import '../surah_args.dart';

class QuranDetailBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    final surahArgs = args is SurahArgs ? args : const SurahArgs(1);
    Get.lazyPut<QuranDetailController>(() => QuranDetailController(surahArgs));
  }
}
