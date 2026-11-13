import 'package:get/get.dart';

import '../../bookmarks/controllers/bookmarks_controller.dart';
import '../controllers/quran_list_controller.dart';

class QuranListBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<QuranListController>(QuranListController.new);
    Get.lazyPut<BookmarksController>(BookmarksController.new);
  }
}
