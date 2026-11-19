import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../core/theme/tokens.dart';
import '../../core/ui_state.dart';
import '../../core/widgets/empty_state.dart';
import '../../core/widgets/error_state.dart';
import '../../routes/app_routes.dart';
import '../hadith_detail/hadith_detail_args.dart';
import '../quran_detail/surah_args.dart';
import 'controllers/home_controller.dart';
import 'widgets/daily_card.dart';
import 'widgets/daily_settings_sheet.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({required this.dataVersion, super.key});

  final String dataVersion;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(
              NuraSpace.s16,
              NuraSpace.s8,
              NuraSpace.s8,
              0,
            ),
            child: Row(
              children: [
                Expanded(child: Text('Beranda', style: text.headlineSmall)),
                IconButton(
                  tooltip: 'Pengaturan harian',
                  icon: const NuraIcon(NuraIcons.tune),
                  style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
                  onPressed: () => showDailySettingsSheet(context),
                ),
              ],
            ),
          ),
          Expanded(child: Obx(() => _body(controller.cards.value))),
          Padding(
            padding: const EdgeInsets.all(NuraSpace.s8),
            child: Text('data_version $dataVersion', style: text.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _body(UiState<DailyCards> state) => switch (state) {
    UiLoading() => const Center(child: CircularProgressIndicator()),
    UiEmpty() => const EmptyState(title: 'Belum ada konten harian'),
    UiError() => ErrorState(
      title: 'Konten harian tidak dapat dibaca',
      description: '',
      onRetry: controller.refreshForToday,
    ),
    UiData(:final value) => ListView(
      padding: const EdgeInsets.all(NuraSpace.s16),
      children: [
        if (value.ayah case final ayah?) ...[
          DailyAyahCard(
            content: ayah,
            onOpen: ayah.ayahRef == null
                ? null
                : () => Get.toNamed(
                    Routes.surah,
                    arguments: SurahArgs(
                      ayah.ayahRef?.surah ?? 0,
                      ayah.ayahRef?.ayah ?? 0,
                    ),
                  ),
          ),
          if (value.hadith != null) const SizedBox(height: NuraSpace.s16),
        ],
        if (value.hadith case final hadith?)
          DailyHadithCard(
            content: hadith,
            onOpen: hadith.hadithRef == null
                ? null
                : () => Get.toNamed(
                    Routes.hadithDetail,
                    arguments: HadithDetailArgs(
                      hadith.hadithRef?.slug ?? '',
                      hadith.hadithRef?.number ?? 0,
                    ),
                  ),
          ),
      ],
    ),
  };
}
