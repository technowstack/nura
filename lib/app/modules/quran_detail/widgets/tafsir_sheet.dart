import 'package:flutter/material.dart';

import '../../../core/theme/tokens.dart';
import '../../../data/models/ayah.dart';

Future<void> showTafsirSheet(
  BuildContext context, {
  required List<Ayah> ayahs,
  required int initialIndex,
  required String surahName,
}) {
  final scheme = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    barrierColor: scheme.scrim.withValues(alpha: 0.32),
    constraints: BoxConstraints(
      maxHeight: MediaQuery.sizeOf(context).height * 0.9,
    ),
    builder: (_) => _TafsirSheet(
      ayahs: ayahs,
      initialIndex: initialIndex,
      surahName: surahName,
    ),
  );
}

class _TafsirSheet extends StatefulWidget {
  const _TafsirSheet({
    required this.ayahs,
    required this.initialIndex,
    required this.surahName,
  });

  final List<Ayah> ayahs;
  final int initialIndex;
  final String surahName;

  @override
  State<_TafsirSheet> createState() => _TafsirSheetState();
}

class _TafsirSheetState extends State<_TafsirSheet> {
  late int _index = widget.initialIndex;

  void _go(int delta) => setState(() => _index += delta);

  @override
  Widget build(BuildContext context) {
    final ayah = widget.ayahs[_index];
    final text = Theme.of(context).textTheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: NuraSpace.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: NuraSpace.s8),
            Center(
              child: Container(
                width: 32,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.outlineVariant,
                  borderRadius: BorderRadius.circular(NuraRadius.full),
                ),
              ),
            ),
            const SizedBox(height: NuraSpace.s16),
            Text('Tafsir Kemenag', style: text.titleMedium),
            Text(
              '${widget.surahName} · ayat ${ayah.ayahNumber}',
              style: text.bodySmall,
            ),
            const SizedBox(height: NuraSpace.s12),
            Flexible(
              child: SingleChildScrollView(
                key: ValueKey(_index),
                child: Text(
                  ayah.tafsir.isEmpty
                      ? 'Tafsir belum tersedia untuk ayat ini'
                      : ayah.tafsir,
                  style: text.bodyMedium,
                ),
              ),
            ),
            const SizedBox(height: NuraSpace.s8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: _index > 0 ? () => _go(-1) : null,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Sebelumnya'),
                ),
                TextButton.icon(
                  onPressed: _index < widget.ayahs.length - 1
                      ? () => _go(1)
                      : null,
                  iconAlignment: IconAlignment.end,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Berikutnya'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
