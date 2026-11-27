import 'package:get/get.dart';

import '../home/controllers/home_controller.dart';
import '../quran_list/controllers/quran_list_controller.dart';

/// Updates the screens that show the last read as soon as it is marked, by
/// whatever path the reader was opened.
void notifyLastReadChanged() {
  if (Get.isRegistered<HomeController>()) {
    Get.find<HomeController>().refreshLastRead();
  }
  if (Get.isRegistered<QuranListController>()) {
    Get.find<QuranListController>().refreshMarkers();
  }
}
