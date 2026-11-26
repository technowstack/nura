import 'package:nura/app/core/nura_icons.dart';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/models/daily_content.dart';
import '../theme/app_theme.dart';
import '../theme/nura_colors.dart';
import '../theme/tokens.dart';

/// Static widget drawn into the home screen widget PNG (no buttons). Provides
/// its own Theme and MediaQuery so it renders off-screen.
class DailyWidgetImage extends StatelessWidget {
  const DailyWidgetImage({
    required this.content,
    required this.size,
    required this.brightness,
    super.key,
  });

  final DailyContent content;

  /// Size in dp, as reported by the launcher or the design default.
  final Size size;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final theme = brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;
    final scheme = theme.colorScheme;
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: Theme(
        data: theme,
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLowest,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(NuraRadius.xl),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NuraRadius.xl),
              child: Stack(
                children: [
                  if (content.kind == DailyKind.ayah)
                    Positioned(
                      right: -NuraSpace.s24,
                      top: -NuraSpace.s24,
                      child: NuraIcon(
                        NuraIcons.brightnessLow,
                        size: 120,
                        color:
                            (theme.extension<NuraColors>() ?? NuraColors.light)
                                .ornament,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(NuraSpace.s12),
                    child: _content(theme),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Whole lines of Arabic and translation that fit in [height]. Space goes
  /// to one line each first, then alternately to more, so no line is ever cut.
  static (int, int) _fit(double height, double arab, double tr) {
    var a = 0, t = 0;
    var left = height;
    void arabLine() {
      final cost = arab + (a == 0 ? NuraSpace.s4 : 0);
      if (cost <= left) {
        a++;
        left -= cost;
      }
    }

    void trLine() {
      final cost = tr + (t == 0 ? NuraSpace.s4 : 0);
      if (cost <= left) {
        t++;
        left -= cost;
      }
    }

    for (final add in [
      arabLine,
      trLine,
      trLine,
      arabLine,
      trLine,
      arabLine,
      trLine,
    ]) {
      add();
    }
    return (a, t);
  }

  Widget _content(ThemeData theme) {
    final scheme = theme.colorScheme;
    return Builder(
      builder: (context) {
        final arab = context.nuraText.arabicCard;
        final tr = context.nuraText.translation;
        final accent = context.nuraColors.iconAccent;
        final surahName = content.surahNameArab;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    content.kind == DailyKind.ayah
                        ? 'Ayat hari ini'
                        : 'Hadis hari ini',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.labelLarge?.copyWith(color: accent),
                  ),
                ),
                if (surahName != null)
                  Flexible(
                    child: Text(
                      surahName,
                      textDirection: TextDirection.rtl,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.nuraText.arabicTitle.copyWith(
                        color: accent,
                      ),
                    ),
                  ),
              ],
            ),
            // The strut pins each line to the token height, so the number of
            // lines that fit is exact even with tall device fonts.
            Expanded(
              child: LayoutBuilder(
                builder: (context, box) {
                  final (arabLines, trLines) = _fit(
                    box.maxHeight,
                    // The type tokens always define size and height.
                    arab.fontSize! * arab.height!,
                    tr.fontSize! * tr.height!,
                  );
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (arabLines > 0) ...[
                        const SizedBox(height: NuraSpace.s4),
                        SizedBox(
                          width: double.infinity,
                          child: Text(
                            content.arab,
                            textDirection: TextDirection.rtl,
                            textAlign: TextAlign.right,
                            maxLines: arabLines,
                            overflow: TextOverflow.ellipsis,
                            strutStyle: StrutStyle.fromTextStyle(
                              arab,
                              forceStrutHeight: true,
                            ),
                            style: arab.copyWith(
                              color: context.nuraColors.arabicText,
                            ),
                          ),
                        ),
                      ],
                      if (trLines > 0) ...[
                        const SizedBox(height: NuraSpace.s4),
                        Text(
                          content.translation,
                          maxLines: trLines,
                          overflow: TextOverflow.ellipsis,
                          strutStyle: StrutStyle.fromTextStyle(
                            tr,
                            forceStrutHeight: true,
                          ),
                          style: tr.copyWith(color: scheme.onSurface),
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: NuraSpace.s4),
            Text(
              content.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(color: accent),
            ),
          ],
        );
      },
    );
  }
}

/// Renders [c] off-screen to PNG bytes of `dp * pixelRatio` pixels.
Future<Uint8List> renderDailyImage(
  DailyContent c, {
  required Size dp,
  required double pixelRatio,
  required Brightness brightness,
}) async {
  final boundary = RenderRepaintBoundary();
  final pipelineOwner = PipelineOwner();
  final buildOwner = BuildOwner(focusManager: FocusManager());
  final view = ui.PlatformDispatcher.instance.implicitView;
  if (view == null) throw StateError('No implicit view to render into');
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(alignment: Alignment.center, child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(dp),
      devicePixelRatio: pixelRatio,
    ),
  );
  pipelineOwner.rootNode = renderView;
  renderView.prepareInitialFrame();
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: DailyWidgetImage(content: c, size: dp, brightness: brightness),
    ),
  ).attachToRenderTree(buildOwner);
  buildOwner.buildScope(root);
  buildOwner.finalizeTree();
  pipelineOwner.flushLayout();
  pipelineOwner.flushCompositingBits();
  pipelineOwner.flushPaint();
  final image = await boundary.toImage(pixelRatio: pixelRatio);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (data == null) throw StateError('PNG encoding returned no data');
  return data.buffer.asUint8List();
}
