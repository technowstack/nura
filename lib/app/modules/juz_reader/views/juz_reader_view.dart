import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../../core/ui_state.dart';
import '../../../core/widgets/empty_state.dart';
import '../../../core/widgets/error_state.dart';
import '../../../data/models/ayah.dart';
import '../../quran_detail/widgets/ayah_card.dart';
import '../../quran_detail/widgets/surah_header_card.dart';
import '../../quran_detail/widgets/tafsir_sheet.dart';
import '../../../routes/app_routes.dart';
import '../controllers/juz_reader_controller.dart';
import '../juz_item.dart';

class JuzReaderView extends GetView<JuzReaderController> {
  const JuzReaderView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    // Save the pending last read on pop (see QuranDetailView).
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) c.flushLastRead();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Juz ${c.args.number}'),
              Obx(
                () => c.rangeText.value.isEmpty
                    ? const SizedBox.shrink()
                    : Text(
                        c.rangeText.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
              ),
            ],
          ),
          actions: [
            Obx(() {
              if (!c.audioVisible.value || c.state.value is! UiData) {
                return const SizedBox.shrink();
              }
              final off = c.offline.value;
              return Semantics(
                label: off ? 'Putar juz, butuh internet' : null,
                child: IconButton(
                  tooltip: off ? 'Butuh internet' : 'Putar juz',
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                  icon: const NuraIcon(NuraIcons.playArrow),
                  onPressed: off ? null : c.playJuz,
                ),
              );
            }),
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
          final lastRead = c.lastRead.value;
          // Touch audio state here so audio changes rebuild the list.
          c.playerState;
          c.audioVisible.value;
          c.offline.value;
          final playing = c.playingRef.value;
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
              itemCount: value.length,
              itemBuilder: (_, i) => switch (value[i]) {
                SurahHeaderItem(:final surah, :final withBasmalah) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: SurahHeaderCard(
                    surah: surah,
                    basmalah: c.basmalah ?? '',
                    showBismillah: withBasmalah,
                  ),
                ),
                AyahItem(:final ayah) => AyahCard(
                  ayah: ayah,
                  audio: c.audioStateOf(
                    AyahRef(ayah.surahNumber, ayah.ayahNumber),
                  ),
                  playing:
                      playing?.surah == ayah.surahNumber &&
                      playing?.ayah == ayah.ayahNumber,
                  onAudio: () => c.toggleAyahAudio(
                    AyahRef(ayah.surahNumber, ayah.ayahNumber),
                  ),
                  onPlayFromHere: () => c.playFromAyah(
                    AyahRef(ayah.surahNumber, ayah.ayahNumber),
                  ),
                  bookmarked: marked.contains(
                    AyahRef(ayah.surahNumber, ayah.ayahNumber),
                  ),
                  lastRead:
                      lastRead?.surah == ayah.surahNumber &&
                      lastRead?.ayah == ayah.ayahNumber,
                  prefs: prefs,
                  onBookmark: () => c.toggleBookmark(ayah),
                  onCopy: () => c.copyAyah(ayah),
                  onTafsir: () => _tafsir(context, c, ayah),
                ),
              },
            ),
          };
        }),
      ),
    );
  }

  Future<void> _tafsir(
    BuildContext context,
    JuzReaderController c,
    Ayah ayah,
  ) async {
    final t = c.tafsirFor(ayah);
    if (t == null) return;
    await showTafsirSheet(
      context,
      ayahs: t.ayahs,
      initialIndex: t.index,
      surahName: t.surahName,
    );
    c.refreshBookmarks();
  }
}
