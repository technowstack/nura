import 'package:get/get.dart';

class ShellController extends GetxController {
  static const prayerTab = 3;

  int index = 0;

  /// Mirrors [index] for listeners outside the tab bar (e.g. the prayer
  /// countdown, which only runs while its tab is selected).
  final tab = 0.obs;

  void select(int i) {
    index = i;
    tab.value = i;
    update();
  }
}
