import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_controller.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/ui_state.dart';
import '../controllers/quran_detail_controller.dart';

Future<void> showReadingSettingsSheet(
  BuildContext context, {
  required QuranDetailController controller,
  required ThemeController theme,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: scheme.scrim.withValues(alpha: 0.32),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _ReadingSettingsSheet(controller: controller, theme: theme),
  );
}

class _ReadingSettingsSheet extends StatelessWidget {
  const _ReadingSettingsSheet({required this.controller, required this.theme});

  final QuranDetailController controller;
  final ThemeController theme;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          NuraSpace.s20,
          NuraSpace.s8,
          NuraSpace.s20,
          NuraSpace.s16,
        ),
        child: Obx(() {
          final prefs = controller.prefs.value;
          final mode = theme.mode.value;
          final s = controller.state.value;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: ExcludeSemantics(
                  child: Container(
                    width: 32,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(NuraRadius.full),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: NuraSpace.s16),
              Semantics(
                header: true,
                child: Text('Pengaturan tampilan', style: text.titleMedium),
              ),
              const SizedBox(height: NuraSpace.s12),
              if (s is UiData<SurahContent>)
                Text(
                  s.value.basmalah,
                  textAlign: TextAlign.center,
                  textDirection: TextDirection.rtl,
                  style: context.nuraText.arabicReading.copyWith(
                    fontSize: prefs.arabicFontSize,
                    color: context.nuraColors.arabicText,
                  ),
                ),
              const SizedBox(height: NuraSpace.s12),
              Text('Ukuran teks Arab', style: text.labelLarge),
              Slider(
                value: prefs.arabicFontSize.clamp(20, 40),
                min: 20,
                max: 40,
                divisions: 10,
                label: prefs.arabicFontSize.round().toString(),
                semanticFormatterCallback: (v) =>
                    'Ukuran teks Arab ${v.round()}',
                onChanged: controller.setArabicFontSize,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Tampilkan terjemahan'),
                value: prefs.showTranslation,
                onChanged: controller.setShowTranslation,
              ),
              const SizedBox(height: NuraSpace.s8),
              Text('Tema', style: text.labelLarge),
              const SizedBox(height: NuraSpace.s8),
              SegmentedButton<ThemeMode>(
                showSelectedIcon: true,
                selected: {mode},
                onSelectionChanged: (v) => theme.setMode(v.first),
                segments: const [
                  ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
                  ButtonSegment(value: ThemeMode.light, label: Text('Terang')),
                  ButtonSegment(value: ThemeMode.dark, label: Text('Gelap')),
                ],
              ),
            ],
          );
        }),
      ),
    );
  }
}
