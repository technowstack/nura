import 'package:get/get.dart';

import '../app_bootstrap.dart';
import '../modules/home/home_view.dart';
import '../modules/onboarding/onboarding_view.dart';
import 'app_routes.dart';

List<GetPage<dynamic>> appPages(BootstrapSuccess ready) => [
  GetPage(
    name: Routes.home,
    page: () => HomeView(dataVersion: ready.content.dataVersion),
  ),
  GetPage(
    name: Routes.onboarding,
    page: () => OnboardingView(user: ready.user),
  ),
];
