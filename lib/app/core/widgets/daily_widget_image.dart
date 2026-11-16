import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../data/models/daily_content.dart';
import '../theme/app_theme.dart';
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

  /// Size in dp; a height of 200 or less is the compact 4x2 layout.
  final Size size;
  final Brightness brightness;

  @override
  Widget build(BuildContext context) {
    final compact = size.height <= 200;
    final theme = brightness == Brightness.dark
        ? AppTheme.dark
        : AppTheme.light;
    final scheme = theme.colorScheme;
    final isAyah = content.kind == DailyKind.ayah;
    return MediaQuery(
      data: MediaQueryData(size: size),
      child: Theme(
        data: theme,
        child: SizedBox.fromSize(
          size: size,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: isAyah
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(NuraRadius.xl),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(NuraRadius.xl),
              child: Stack(
                children: [
                  if (isAyah)
                    Positioned(
                      right: -NuraSpace.s24,
                      top: -NuraSpace.s24,
                      child: Icon(
                        Icons.brightness_low,
                        size: 120,
                        color: context.nuraColors.ornament,
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.all(NuraSpace.s12),
                    child: _content(theme, compact),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _content(ThemeData theme, bool compact) {
    final scheme = theme.colorScheme;
    final arabLines = compact ? 1 : 2;
    final trLines = compact ? 1 : 3;
    return Builder(
      builder: (context) {
        final arab = context.nuraText.arabicCard;
        final tr = context.nuraText.translation;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              content.kind == DailyKind.ayah
                  ? 'Ayat hari ini'
                  : 'Hadis hari ini',
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: NuraSpace.s4),
            // Device fonts (Arabic fallback) can have taller line metrics than
            // the token line height: the strut pins the line height, and the
            // flex shares shrink the two texts instead of overflowing.
            Flexible(
              flex: 44 * arabLines,
              child: SizedBox(
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
                  style: arab.copyWith(color: context.nuraColors.arabicText),
                ),
              ),
            ),
            const SizedBox(height: NuraSpace.s4),
            Flexible(
              flex: 24 * trLines,
              child: Text(
                content.translation,
                maxLines: trLines,
                overflow: TextOverflow.ellipsis,
                strutStyle: StrutStyle.fromTextStyle(
                  tr,
                  forceStrutHeight: true,
                ),
                style: tr.copyWith(color: scheme.onSurface),
              ),
            ),
            const SizedBox(height: NuraSpace.s4),
            Text(
              content.reference,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                color: scheme.primary,
              ),
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
