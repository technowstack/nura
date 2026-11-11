import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/theme/theme_controller.dart';
import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../controllers/quran_detail_controller.dart';
import '../widgets/ayah_card.dart';
import '../widgets/reading_settings_sheet.dart';
import '../widgets/surah_header_card.dart';
import '../widgets/tafsir_sheet.dart';

class QuranDetailView extends GetView<QuranDetailController> {
  const QuranDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final s = c.state.value;
          if (s is! UiData<SurahContent>) return const Text('Baca Surah');
          final surah = s.value.surah;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(surah.nameLatin),
              Text(
                '${surah.nameLatin} · ${surah.ayahCount} ayat',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }),
        actions: [
          IconButton(
            tooltip: 'Pengaturan tampilan',
            constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
            icon: const Icon(Icons.tune),
            onPressed: () => showReadingSettingsSheet(
              context,
              controller: c,
              theme: Get.find<ThemeController>(),
            ),
          ),
        ],
      ),
      body: Obx(() {
        // Read observables here, not in itemBuilder, so changes rebuild.
        final marked = c.bookmarked.toSet();
        final prefs = c.prefs.value;
        return switch (c.state.value) {
          UiLoading() => const Center(child: CircularProgressIndicator()),
          UiEmpty() => const EmptyState(title: 'Ayat belum tersedia'),
          UiError(:final message) => ErrorState(
            title: 'Gagal memuat',
            description: message,
            onRetry: c.load,
          ),
          UiData(:final value) => SuperListView.builder(
            listController: c.listController,
            itemCount: value.ayahs.length + 1,
            itemBuilder: (_, i) {
              if (i == 0) {
                final n = value.surah.number;
                return Padding(
                  padding: const EdgeInsets.all(20),
                  child: SurahHeaderCard(
                    surah: value.surah,
                    basmalah: value.basmalah,
                    showBismillah: n != 1 && n != 9,
                  ),
                );
              }
              final ayah = value.ayahs[i - 1];
              return AyahCard(
                ayah: ayah,
                bookmarked: marked.contains(ayah.ayahNumber),
                lastRead: false,
                prefs: prefs,
                onBookmark: () => c.toggleBookmark(ayah.ayahNumber),
                onCopy: () => c.copyAyah(ayah),
                onTafsir: () => showTafsirSheet(
                  context,
                  ayahs: value.ayahs,
                  initialIndex: i - 1,
                  surahName: value.surah.nameLatin,
                ),
              );
            },
          ),
        };
      }),
    );
  }
}
