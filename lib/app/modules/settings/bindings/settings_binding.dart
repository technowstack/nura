import 'package:get/get.dart';

import '../controllers/settings_controller.dart';

class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    // fenix: the controller is shared by the Pengaturan tab and the /settings
    // route; GetX would otherwise delete it with whichever route was current
    // when it was first built. Visits re-read the stores via onVisit().
    Get.lazyPut<SettingsController>(SettingsController.new, fenix: true);
  }
}
