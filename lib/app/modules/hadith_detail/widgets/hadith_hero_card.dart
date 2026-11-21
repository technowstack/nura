import 'package:flutter/material.dart';

import '../../../core/format_thousands.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/tokens.dart';
import '../hadith_detail_content.dart';

/// Hero card: book, number and count on the left, Arabic book name right.
class HadithHeroCard extends StatelessWidget {
  const HadithHeroCard({required this.content, super.key});

  final HadithDetailContent content;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final label = Theme.of(
      context,
    ).textTheme.bodyMedium?.copyWith(color: colors.onHero);
    final value = label?.copyWith(
      color: colors.onHeroAccent,
      fontWeight: FontWeight.w600,
    );
    Widget row(String l, String v) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '$l  ', style: label),
            TextSpan(text: v, style: value),
          ],
        ),
      ),
    );
    final arab = content.nameArab;
    return DecoratedBox(
      key: const ValueKey('hadith-hero'),
      decoration: BoxDecoration(
        color: colors.hero,
        borderRadius: BorderRadius.circular(NuraRadius.lg),
      ),
      child: Padding(
        padding: const EdgeInsets.all(NuraSpace.s20),
        child: Row(
          children: [
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  row('Kitab', content.title),
                  row('Nomor', '${content.ref.number}'),
                  if (content.hadithCount > 0)
                    row('Jumlah hadis', formatThousands(content.hadithCount)),
                ],
              ),
            ),
            if (arab != null) ...[
              const SizedBox(width: NuraSpace.s12),
              Flexible(
                flex: 2,
                child: FittedBox(
                  key: const ValueKey('hadith-hero-arab'),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    arab,
                    textDirection: TextDirection.rtl,
                    style: context.nuraText.arabicHero.copyWith(
                      color: colors.onHero,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
