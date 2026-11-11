import 'package:get/get.dart';

import '../app_bootstrap.dart';
import '../modules/shell/views/shell_view.dart';
import '../modules/onboarding/onboarding_view.dart';
import 'app_routes.dart';

List<GetPage<dynamic>> appPages(BootstrapSuccess ready) => [
  GetPage(
    name: Routes.home,
    page: () => ShellView(dataVersion: ready.content.dataVersion),
  ),
  GetPage(
    name: Routes.onboarding,
    page: () => OnboardingView(user: ready.user),
  ),
];
