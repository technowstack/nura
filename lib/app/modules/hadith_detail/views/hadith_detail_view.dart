import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui_state.dart';
import '../../../core/widgets/error_state.dart';
import '../controllers/hadith_detail_controller.dart';
import '../hadith_detail_content.dart';
import '../widgets/hadith_action_bar.dart';
import '../widgets/hadith_hero_card.dart';
import '../widgets/hadith_text_card.dart';

class HadithDetailView extends GetView<HadithDetailController> {
  const HadithDetailView({super.key});

  @override
  Widget build(BuildContext context) {
    final c = controller;
    return Scaffold(
      appBar: AppBar(
        title: Obx(() {
          final s = c.state.value;
          if (s is! UiData<HadithDetailContent>) return const Text('Hadis');
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.value.title, maxLines: 1, overflow: TextOverflow.ellipsis),
              Text(
                s.value.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          );
        }),
      ),
      body: Obx(() {
        final prefs = c.prefs.value;
        final hasPrevious = c.hasPrevious.value;
        final hasNext = c.hasNext.value;
        return switch (c.state.value) {
          UiLoading() => const Center(child: CircularProgressIndicator()),
          UiEmpty() => const SizedBox.shrink(),
          UiError(:final message) => ErrorState(
            title: 'Gagal memuat',
            description: message,
            onRetry: c.load,
          ),
          UiData(:final value) => SingleChildScrollView(
            // New key per hadith: scroll position resets to the top.
            key: ValueKey(value.ref),
            padding: const EdgeInsets.all(NuraSpace.s20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                HadithHeroCard(content: value),
                const SizedBox(height: NuraSpace.s12),
                HadithTextCard(content: value, prefs: prefs),
                const SizedBox(height: NuraSpace.s12),
                Text(
                  value.referenceLabel,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    color: context.nuraColors.iconAccent,
                  ),
                ),
                const SizedBox(height: NuraSpace.s12),
                HadithActionBar(
                  bookmarked: c.bookmarked.value,
                  onBookmark: c.toggleBookmark,
                  onCopy: c.copy,
                ),
                const SizedBox(height: NuraSpace.s24),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: hasPrevious
                              ? () => c.goTo(next: false)
                              : null,
                          child: const Text(
                            'Sebelumnya',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                      const SizedBox(width: NuraSpace.s12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: hasNext ? () => c.goTo(next: true) : null,
                          child: const Text(
                            'Berikutnya',
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        };
      }),
    );
  }
}
