import 'package:get/get.dart';

import '../controllers/hadith_list_controller.dart';
import '../hadith_list_args.dart';

class HadithListBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    // Invalid sentinel (empty slug): load() shows an error, never another book.
    final listArgs = args is HadithListArgs
        ? args
        : const HadithListArgs('', '');
    Get.lazyPut<HadithListController>(() => HadithListController(listArgs));
  }
}
