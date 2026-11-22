import 'package:get/get.dart';

import '../controllers/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    // Not fenix: every visit re-reads the stores, so changes made on the
    // Sholat tab or Beranda while away are shown.
    Get.lazyPut<SettingsController>(SettingsController.new);
  }
}
