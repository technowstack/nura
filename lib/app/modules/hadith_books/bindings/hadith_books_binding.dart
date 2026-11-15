import 'package:get/get.dart';

import '../controllers/hadith_books_controller.dart';

class HadithBooksBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HadithBooksController>(HadithBooksController.new);
  }
}
