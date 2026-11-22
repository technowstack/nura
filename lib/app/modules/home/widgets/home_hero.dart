import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../core/nura_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/nura_colors.dart';
import '../../../core/theme/tokens.dart';
import '../../../routes/app_routes.dart';
import 'hero_silhouette.dart';
import 'home_hero_data.dart';

/// Space the content sheet overlaps the hero.
const double heroSheetOverlap = NuraSpace.s24;

/// Full-bleed hero behind the status bar (about 360 tall).
class HomeHero extends StatelessWidget {
  const HomeHero({required this.data, super.key});

  final HomeHeroData data;

  @override
  Widget build(BuildContext context) {
    final c = context.nuraColors;
    final text = Theme.of(context).textTheme;
    final top = MediaQuery.paddingOf(context).top;
    final onHero = TextStyle(color: c.onHero);
    return Semantics(
      container: true,
      child: Container(
        key: const Key('home-hero'),
        color: c.hero,
        constraints: BoxConstraints(minHeight: 360 + top),
        child: Stack(
          children: [
            // The page heading for screen readers: first in reading order,
            // a 1 dp node that draws nothing.
            Positioned(
              left: 0,
              top: 0,
              width: 1,
              height: 1,
              child: Semantics(container: true, header: true, label: 'Beranda'),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: heroSilhouetteHeight,
              child: ExcludeSemantics(
                child: CustomPaint(painter: HeroSilhouettePainter(c.heroShape)),
              ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(
                NuraSpace.s16,
                top + NuraSpace.s8,
                NuraSpace.s8,
                heroSheetOverlap + NuraSpace.s16,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      NuraIcon(NuraIcons.locationOn, color: c.onHero),
                      const SizedBox(width: NuraSpace.s8),
                      Expanded(
                        child: Text(
                          data.locationLabel,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: text.titleMedium?.merge(onHero),
                        ),
                      ),
                      _action(
                        'Cari',
                        NuraIcons.search,
                        c.onHero,
                        () => Get.toNamed(Routes.search),
                      ),
                    ],
                  ),
                  const SizedBox(height: NuraSpace.s16),
                  Text(data.hijriDate, style: text.titleMedium?.merge(onHero)),
                  Text(
                    data.clock,
                    style: text.displaySmall
                        ?.merge(onHero)
                        .copyWith(fontSize: 48),
                  ),
                  if (data.countdownLabel case final label?)
                    Text.rich(
                      TextSpan(
                        text: label,
                        style: text.titleMedium?.merge(onHero),
                        children: [
                          TextSpan(
                            text: data.countdownDuration,
                            style: TextStyle(color: c.onHeroAccent),
                          ),
                        ],
                      ),
                    ),
                  if (data.approximate)
                    Text(
                      'Jadwal perkiraan, dihitung offline',
                      style: text.bodyMedium?.merge(onHero),
                    ),
                  const SizedBox(height: NuraSpace.s24),
                  if (data.times.isEmpty)
                    Text(data.emptyText, style: text.bodyLarge?.merge(onHero))
                  else
                    _times(context, c, text),
                ],
              ),
            ),
            // The sheet's rounded top edge, drawn over the hero's reserved
            // bottom space so the body below needs no negative layout.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: heroSheetOverlap,
              child: DecoratedBox(
                key: const Key('home-sheet-cap'),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(NuraRadius.xl),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _action(String tip, IconData icon, Color color, VoidCallback onTap) =>
      IconButton(
        tooltip: tip,
        icon: NuraIcon(icon, color: color),
        style: IconButton.styleFrom(minimumSize: const Size(48, 48)),
        onPressed: onTap,
      );

  Widget _times(BuildContext context, NuraColors c, TextTheme text) => Row(
    children: [
      for (final (i, t) in data.times.indexed)
        Expanded(
          child: _TimeCell(
            time: t,
            next: i == data.nextIndex,
            color: i == data.nextIndex ? c.onHeroAccent : c.onHero,
            text: text,
          ),
        ),
    ],
  );
}

class _TimeCell extends StatelessWidget {
  const _TimeCell({
    required this.time,
    required this.next,
    required this.color,
    required this.text,
  });

  final HeroPrayerTime time;
  final bool next;
  final Color color;
  final TextTheme text;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      NuraIcon(time.icon, color: color),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(time.name, style: text.labelMedium?.copyWith(color: color)),
      ),
      FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(time.time, style: text.labelLarge?.copyWith(color: color)),
      ),
      // A dot, so the next time is not marked by color alone.
      Container(
        key: next ? const Key('hero-next-dot') : null,
        width: 6,
        height: 6,
        margin: const EdgeInsets.only(top: NuraSpace.s4),
        decoration: BoxDecoration(
          color: next ? color : Colors.transparent,
          shape: BoxShape.circle,
        ),
      ),
    ],
  );
}
