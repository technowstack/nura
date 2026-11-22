import 'package:get/get.dart';

import '../../bookmarks/controllers/bookmarks_controller.dart';
import '../controllers/quran_list_controller.dart';

/// fenix: tab controllers outlive whichever route is current when first built.
class QuranListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QuranListController>(QuranListController.new, fenix: true);
    Get.lazyPut<BookmarksController>(BookmarksController.new, fenix: true);
  }
}
