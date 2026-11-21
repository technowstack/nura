import 'package:nura/app/core/nura_icons.dart';
import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../../../core/widgets/nura_card.dart';
import '../../../data/models/daily_content.dart';

const _minTarget = Size(48, 48);

/// Arabic text, translation and (always visible) reference shared by both
/// cards.
class _Body extends StatelessWidget {
  const _Body({
    required this.label,
    required this.content,
    required this.reference,
    this.maxLines,
    this.trailing,
  });

  final String label;
  final DailyContent content;
  final VoidCallback? reference;
  final int? maxLines;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final overflow = maxLines == null ? null : TextOverflow.ellipsis;
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: context.nuraColors.iconAccent,
          ),
        ),
        const SizedBox(height: NuraSpace.s12),
        SizedBox(
          width: double.infinity,
          child: Text(
            content.arab,
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.right,
            maxLines: maxLines,
            overflow: overflow,
            style: context.nuraText.arabicCard.copyWith(
              color: context.nuraColors.arabicText,
            ),
          ),
        ),
        const SizedBox(height: NuraSpace.s12),
        Text(
          content.translation,
          maxLines: maxLines,
          overflow: overflow,
          style: context.nuraText.translation.copyWith(color: scheme.onSurface),
        ),
        const SizedBox(height: NuraSpace.s8),
        if (trailing == null)
          TextButton(
            onPressed: reference,
            style: TextButton.styleFrom(minimumSize: _minTarget),
            child: Text(content.reference),
          )
        else
          // Reference shrinks with an ellipsis; the link stays on the right.
          LayoutBuilder(
            builder: (context, box) => Row(
              children: [
                Expanded(
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton(
                      onPressed: reference,
                      style: TextButton.styleFrom(minimumSize: _minTarget),
                      child: Text(
                        content.reference,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ),
                // Cap the link so a huge text scale shrinks it, never overflows.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * 0.65),
                  child: trailing,
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Prominent ayah card with a thin ornament in the background; the whole
/// card and its reference open the surah at that ayah.
class DailyAyahCard extends StatelessWidget {
  const DailyAyahCard({required this.content, required this.onOpen, super.key});

  final DailyContent content;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => NuraCard(
    padding: EdgeInsets.zero,
    onTap: onOpen,
    child: Stack(
      children: [
        Positioned(
          right: -NuraSpace.s24,
          top: -NuraSpace.s24,
          child: ExcludeSemantics(
            child: NuraIcon(
              NuraIcons.brightnessLow,
              size: 120,
              color: context.nuraColors.ornament,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(NuraSpace.s16),
          child: _Body(
            label: 'Ayat hari ini',
            content: content,
            reference: onOpen,
          ),
        ),
      ],
    ),
  );
}

/// Simpler hadith card: matan, translation, reference and "Baca selengkapnya"
/// (both open the hadith detail).
class DailyHadithCard extends StatelessWidget {
  const DailyHadithCard({
    required this.content,
    required this.onOpen,
    super.key,
  });

  final DailyContent content;
  final VoidCallback? onOpen;

  @override
  Widget build(BuildContext context) => NuraCard(
    child: _Body(
      label: 'Hadis hari ini',
      content: content,
      reference: onOpen,
      maxLines: 6,
      trailing: TextButton(
        onPressed: onOpen,
        style: TextButton.styleFrom(minimumSize: _minTarget),
        child: const Text(
          'Baca selengkapnya',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    ),
  );
}
