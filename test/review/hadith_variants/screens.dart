import 'package:flutter/material.dart';
import 'package:nura/app/core/nura_icons.dart';
import 'package:nura/app/core/theme/app_theme.dart';
import 'package:nura/app/core/theme/tokens.dart';
import 'package:nura/app/core/widgets/nura_card.dart';
import 'package:nura/app/core/widgets/ornament_badge.dart';

import 'data.dart';

class _TopBar extends StatelessWidget {
  const _TopBar(this.title, {this.subtitle});
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SizedBox(
      height: 64,
      child: Row(
        children: [
          const SizedBox(width: NuraSpace.s8),
          const SizedBox(
            width: 48,
            height: 48,
            child: NuraIcon(NuraIcons.arrowBack, semanticLabel: 'Kembali'),
          ),
          const SizedBox(width: NuraSpace.s4),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: t.titleLarge),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: t.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

Widget _page(BuildContext context, Widget top, Widget body) => Scaffold(
  body: SafeArea(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        top,
        Expanded(child: body),
      ],
    ),
  ),
);

/// K: book list.
class KitabScreen extends StatelessWidget {
  const KitabScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _page(
      context,
      const _TopBar('Hadis'),
      ListView(
        padding: const EdgeInsets.fromLTRB(
          NuraSpace.s16,
          NuraSpace.s8,
          NuraSpace.s16,
          NuraSpace.s16,
        ),
        children: [
          for (final k in kitab)
            Padding(
              padding: const EdgeInsets.only(bottom: NuraSpace.s8),
              child: NuraCard(
                onTap: () {},
                child: Row(
                  children: [
                    NuraIcon(
                      NuraIcons.menuBook,
                      size: 24,
                      color: context.nuraColors.iconAccent,
                    ),
                    const SizedBox(width: NuraSpace.s16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(k.$2, style: t.titleMedium),
                          Text(
                            countLabel(k.$3),
                            style: t.bodyMedium?.copyWith(
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const NuraIcon(NuraIcons.chevronRight),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

Widget _bookmark(BuildContext context) => SizedBox(
  width: 32,
  height: 32,
  child: NuraIcon(
    NuraIcons.bookmark,
    filled: true,
    color: Theme.of(context).colorScheme.primary,
    semanticLabel: 'Ditandai',
  ),
);

/// L-A: cards.
class ListA extends StatelessWidget {
  const ListA({required this.items, super.key});
  final List<RealHadith> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _page(
      context,
      const _TopBar('Shahih Bukhari'),
      ListView(
        padding: const EdgeInsets.fromLTRB(
          NuraSpace.s16,
          NuraSpace.s8,
          NuraSpace.s16,
          NuraSpace.s16,
        ),
        children: [
          for (final h in items)
            Padding(
              padding: const EdgeInsets.only(bottom: NuraSpace.s8),
              child: NuraCard(
                onTap: () {},
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OrnamentBadge(label: '${h.number}'),
                    const SizedBox(width: NuraSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Shahih Bukhari',
                            style: t.labelMedium?.copyWith(
                              color: context.nuraColors.iconAccent,
                            ),
                          ),
                          const SizedBox(height: NuraSpace.s4),
                          Text(
                            h.preview,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: t.bodyMedium?.copyWith(
                              color: scheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: NuraSpace.s8),
                    SizedBox(
                      width: 32,
                      child: h.number == 3 ? _bookmark(context) : null,
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// L-B: flat rows.
class ListB extends StatelessWidget {
  const ListB({required this.items, super.key});
  final List<RealHadith> items;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return _page(
      context,
      const _TopBar('Shahih Bukhari'),
      ListView(
        children: [
          for (final h in items) ...[
            InkWell(
              onTap: () {},
              child: Padding(
                padding: const EdgeInsets.fromLTRB(
                  NuraSpace.s16,
                  NuraSpace.s16,
                  NuraSpace.s8,
                  NuraSpace.s16,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 44,
                      child: Text(
                        '${h.number}',
                        style: t.titleLarge?.copyWith(
                          color: context.nuraColors.iconAccent,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        h.preview,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodyMedium?.copyWith(color: scheme.onSurface),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: h.number == 3
                          ? Align(
                              alignment: Alignment.topCenter,
                              child: _bookmark(context),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, thickness: 1, color: scheme.outlineVariant),
          ],
        ],
      ),
    );
  }
}

Widget _cell(
  BuildContext context,
  IconData icon,
  String label, {
  bool filled = false,
  Color? color,
  Color? bg,
  double? width,
}) {
  final scheme = Theme.of(context).colorScheme;
  final button = IconButton(
    onPressed: () {},
    style: IconButton.styleFrom(
      backgroundColor: bg ?? scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(NuraRadius.md),
      ),
      minimumSize: const Size.fromHeight(48),
    ),
    icon: NuraIcon(
      icon,
      filled: filled,
      color: color ?? context.nuraColors.iconAccent,
      semanticLabel: label,
    ),
  );
  return width == null
      ? Expanded(child: button)
      : SizedBox(width: width, child: button);
}

Widget _prevNext() => const Row(
  children: [
    Expanded(child: _NavButton('Sebelumnya')),
    SizedBox(width: NuraSpace.s12),
    Expanded(child: _NavButton('Berikutnya')),
  ],
);

class _NavButton extends StatelessWidget {
  const _NavButton(this.label);
  final String label;

  @override
  Widget build(BuildContext context) => OutlinedButton(
    onPressed: () {},
    style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
    child: Text(label),
  );
}

/// D-A: hero + cards.
class DetailA extends StatelessWidget {
  const DetailA({required this.hadith, super.key});
  final RealHadith hadith;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final t = Theme.of(context).textTheme;
    final label = t.bodyMedium?.copyWith(color: colors.onHero);
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
    return _page(
      context,
      const _TopBar('Shahih Bukhari', subtitle: 'No. 14'),
      ListView(
        padding: const EdgeInsets.all(NuraSpace.s16),
        children: [
          Container(
            padding: const EdgeInsets.all(NuraSpace.s20),
            decoration: BoxDecoration(
              color: colors.hero,
              borderRadius: BorderRadius.circular(NuraRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                row('Kitab', 'Shahih Bukhari'),
                row('Nomor', '${hadith.number}'),
                row('Jumlah hadis', formatCount(6638)),
              ],
            ),
          ),
          const SizedBox(height: NuraSpace.s12),
          NuraCard(
            child: SizedBox(
              width: double.infinity,
              child: Text(
                hadith.arab,
                textAlign: TextAlign.right,
                textDirection: TextDirection.rtl,
                style: context.nuraText.arabicCard.copyWith(
                  color: colors.arabicText,
                ),
              ),
            ),
          ),
          const SizedBox(height: NuraSpace.s12),
          NuraCard(
            child: Text(
              hadith.translation,
              style: context.nuraText.translation,
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: NuraSpace.s12),
            child: Text(
              'HR. Bukhari No. ${hadith.number}',
              style: t.labelLarge?.copyWith(color: colors.iconAccent),
            ),
          ),
          SizedBox(
            height: 48,
            child: Row(
              children: [
                _cell(context, NuraIcons.contentCopy, 'Salin hadis'),
                const SizedBox(width: NuraSpace.s8),
                _cell(context, NuraIcons.bookmark, 'Tambah bookmark'),
              ],
            ),
          ),
          const SizedBox(height: NuraSpace.s24),
          _prevNext(),
        ],
      ),
    );
  }
}

String formatCount(int n) => countLabel(n).replaceAll(' hadis', '');

/// D-B: reading sheet.
class DetailB extends StatelessWidget {
  const DetailB({required this.hadith, super.key});
  final RealHadith hadith;

  @override
  Widget build(BuildContext context) {
    final colors = context.nuraColors;
    final scheme = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;
    return Scaffold(
      body: SafeArea(
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _TopBar('Hadis'),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      NuraSpace.s20,
                      NuraSpace.s8,
                      NuraSpace.s20,
                      112,
                    ),
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: NuraSpace.s16,
                            vertical: NuraSpace.s8,
                          ),
                          decoration: BoxDecoration(
                            color: scheme.primaryContainer,
                            borderRadius: BorderRadius.circular(
                              NuraRadius.full,
                            ),
                          ),
                          child: Text(
                            'HR. Bukhari No. ${hadith.number}',
                            style: t.labelLarge?.copyWith(
                              color: scheme.onPrimaryContainer,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: NuraSpace.s24),
                      Text(
                        hadith.arab,
                        textAlign: TextAlign.right,
                        textDirection: TextDirection.rtl,
                        style: context.nuraText.arabicReading.copyWith(
                          color: colors.arabicText,
                        ),
                      ),
                      const SizedBox(height: NuraSpace.s24),
                      Row(
                        children: [
                          Expanded(
                            child: Divider(
                              height: 1,
                              color: scheme.outlineVariant,
                            ),
                          ),
                          const Padding(
                            padding: EdgeInsets.symmetric(
                              horizontal: NuraSpace.s12,
                            ),
                            child: OrnamentBadge(label: '', size: 28),
                          ),
                          Expanded(
                            child: Divider(
                              height: 1,
                              color: scheme.outlineVariant,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: NuraSpace.s24),
                      Text(
                        hadith.translation,
                        style: t.bodyLarge?.copyWith(
                          color: scheme.onSurface,
                          height: 30 / 16,
                        ),
                      ),
                      const SizedBox(height: NuraSpace.s24),
                      _prevNext(),
                    ],
                  ),
                ),
              ],
            ),
            Positioned(
              bottom: NuraSpace.s16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.all(NuraSpace.s4),
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(NuraRadius.xl),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _cell(
                        context,
                        NuraIcons.contentCopy,
                        'Salin hadis',
                        bg: Colors.transparent,
                        width: 72,
                      ),
                      _cell(
                        context,
                        NuraIcons.bookmark,
                        'Tambah bookmark',
                        bg: Colors.transparent,
                        width: 72,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
