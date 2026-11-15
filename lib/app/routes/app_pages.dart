import 'package:get/get.dart';

import '../app_bootstrap.dart';
import '../modules/hadith_detail/bindings/hadith_detail_binding.dart';
import '../modules/hadith_detail/views/hadith_detail_view.dart';
import '../modules/hadith_list/bindings/hadith_list_binding.dart';
import '../modules/hadith_list/views/hadith_list_view.dart';
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
    name: Routes.hadithList,
    page: HadithListView.new,
    binding: HadithListBinding(),
  ),
  GetPage(
    name: Routes.hadithDetail,
    page: HadithDetailView.new,
    binding: HadithDetailBinding(),
  ),
  GetPage(
    name: Routes.onboarding,
    page: () => OnboardingView(user: ready.user),
  ),
];
