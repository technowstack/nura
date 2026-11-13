import 'package:get/get.dart';

import '../app_bootstrap.dart';
import '../modules/quran_detail/bindings/quran_detail_binding.dart';
import '../modules/quran_detail/views/quran_detail_view.dart';
import '../modules/shell/views/shell_view.dart';
import '../modules/onboarding/onboarding_view.dart';
import 'app_routes.dart';

List<GetPage<dynamic>> appPages(BootstrapSuccess ready) => [
  GetPage(
    name: Routes.home,
    page: () => ShellView(dataVersion: ready.content.dataVersion),
  ),
  GetPage(
    name: Routes.surah,
    page: QuranDetailView.new,
    binding: QuranDetailBinding(),
  ),
  GetPage(
    name: Routes.onboarding,
    page: () => OnboardingView(user: ready.user),
  ),
];
