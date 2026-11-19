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
import 'widgets/home_hero.dart';
import 'widgets/last_read_card.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({required this.dataVersion, super.key});

  final String dataVersion;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverToBoxAdapter(
            child: Obx(
              () => HomeHero(
                data: controller.hero.value,
                onTune: () => showDailySettingsSheet(context),
              ),
            ),
          ),
          SliverToBoxAdapter(
            // Pulls the sheet over the hero; the hero reserves this space.
            child: Transform.translate(
              offset: const Offset(0, -heroSheetOverlap),
              child: Container(
                key: const Key('home-sheet'),
                decoration: BoxDecoration(
                  color: scheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(NuraRadius.xl),
                  ),
                ),
                padding: const EdgeInsets.all(NuraSpace.s16),
                child: Column(
                  children: [
                    Obx(
                      () => LastReadCard(
                        info: controller.lastRead.value,
                        onContinue: _continue,
                      ),
                    ),
                    const SizedBox(height: NuraSpace.s16),
                    Obx(() => _body(controller.cards.value)),
                    Padding(
                      padding: const EdgeInsets.all(NuraSpace.s8),
                      child: Text(
                        'data_version $dataVersion',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _continue() async {
    final r = controller.lastRead.value;
    if (r == null) return;
    await Get.toNamed<void>(
      Routes.surah,
      arguments: SurahArgs(r.surah, r.ayah),
    );
    controller.refreshLastRead();
  }

  Widget _body(UiState<DailyCards> state) => switch (state) {
    UiLoading() => const Center(child: CircularProgressIndicator()),
    UiEmpty() => const EmptyState(title: 'Belum ada konten harian'),
    UiError() => ErrorState(
      title: 'Konten harian tidak dapat dibaca',
      description: '',
      onRetry: controller.refreshForToday,
    ),
    UiData(:final value) => Column(
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
