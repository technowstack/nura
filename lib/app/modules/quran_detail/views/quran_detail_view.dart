import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../routes/app_routes.dart';
import '../controllers/quran_detail_controller.dart';
import '../widgets/ayah_card.dart';
import '../widgets/surah_header_card.dart';
import '../widgets/tafsir_sheet.dart';

class QuranDetailView extends GetView<QuranDetailController> {
  const QuranDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // Save the pending last read on pop: onClose runs only after the exit
    // animation, i.e. after the list already refreshed its markers.
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) c.flushLastRead();
      },
      child: Scaffold(
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
                  surah.nameId.isEmpty
                      ? '${surah.ayahCount} ayat'
                      : '${surah.nameId} · ${surah.ayahCount} ayat',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            );
          }),
          actions: [
            IconButton(
              tooltip: 'Pengaturan',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              icon: const NuraIcon(NuraIcons.settings),
              onPressed: () async {
                await Get.toNamed<void>(Routes.settings);
                // Settings may have changed the reading prefs.
                c.refreshPrefs();
              },
            ),
          ],
        ),
        body: Obx(() {
          // Read observables here, not in itemBuilder, so changes rebuild.
          final marked = c.bookmarked.toSet();
          final prefs = c.prefs.value;
          final lastRead = c.lastReadAyah.value;
          // Computed here (not in itemBuilder) so audio changes rebuild.
          final content = c.state.value;
          final audio = content is UiData<SurahContent>
              ? [
                  for (final a in content.value.ayahs)
                    c.audioStateOf(a.ayahNumber),
                ]
              : const <AyahAudioState>[];
          final playing = c.playingAyah.value;
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
              controller: c.scrollController,
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
                      audio: audio.isEmpty
                          ? AyahAudioState.hidden
                          : audio.first,
                      onPlaySurah: c.playSurah,
                    ),
                  );
                }
                final ayah = value.ayahs[i - 1];
                return AyahCard(
                  ayah: ayah,
                  bookmarked: marked.contains(ayah.ayahNumber),
                  lastRead: ayah.ayahNumber == lastRead,
                  prefs: prefs,
                  playing: ayah.ayahNumber == playing,
                  audio: audio[i - 1],
                  onAudio: () => c.toggleAyahAudio(ayah.ayahNumber),
                  onPlayFromHere: () => c.playFromAyah(ayah.ayahNumber),
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
      ),
    );
  }
}
