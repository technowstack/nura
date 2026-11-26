import 'package:get/get.dart';

import '../controllers/onboarding_controller.dart';

class OnboardingBinding extends Bindings {
  @override
  void dependencies() {
    // Not fenix: first built while /onboarding is current, and it must go away
    // with the route (finish() uses offAllNamed).
    Get.lazyPut<OnboardingController>(OnboardingController.new);
  }
}
