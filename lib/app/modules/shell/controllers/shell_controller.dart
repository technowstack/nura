import 'package:get/get.dart';

import '../../home/controllers/home_controller.dart';
import '../../settings/controllers/settings_controller.dart';

class ShellController extends GetxController {
  static const prayerTab = 3;
  static const settingsTab = 4;

  int index = 0;

  /// Mirrors [index] for listeners outside the tab bar (e.g. the prayer
  /// countdown, which only runs while its tab is selected).
  final tab = 0.obs;

  /// The Pengaturan tab is built on first selection, so its controller (and
  /// everything it needs) is not created at startup.
  bool settingsVisited = false;

  void select(int i) {
    final leaving = index == settingsTab && i != settingsTab;
    index = i;
    tab.value = i;
    if (i == settingsTab) settingsVisited = true;
    update();
    if (i == settingsTab) Get.find<SettingsController>().onVisit();
    if (leaving && Get.isRegistered<HomeController>()) {
      Get.find<HomeController>().refreshAfterSettings();
    }
  }
}
