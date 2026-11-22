import 'package:get/get.dart';

import '../controllers/juz_reader_controller.dart';
import '../juz_args.dart';

class JuzReaderBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    // Invalid sentinel: load() shows an error instead of a wrong juz.
    final juzArgs = args is JuzArgs ? args : const JuzArgs(0);
    Get.lazyPut<JuzReaderController>(() => JuzReaderController(juzArgs));
  }
}
