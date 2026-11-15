import 'package:get/get.dart';

import '../controllers/hadith_detail_controller.dart';
import '../hadith_detail_args.dart';

class HadithDetailBinding extends Bindings {
  @override
  void dependencies() {
    final args = Get.arguments;
    // Invalid sentinel (empty slug): load() shows an error, never another hadith.
    final detailArgs = args is HadithDetailArgs
        ? args
        : const HadithDetailArgs('', 0);
    Get.lazyPut<HadithDetailController>(
      () => HadithDetailController(detailArgs),
    );
  }
}
