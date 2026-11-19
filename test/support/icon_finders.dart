import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:nura/app/core/nura_icons.dart';

/// Finds a rendered [Icon] by glyph and fill axis, so tests fail if fill is lost.
Finder bookmarkIcon({required bool filled}) => find.byWidgetPredicate(
  (w) =>
      w is Icon && w.icon == NuraIcons.bookmark && w.fill == (filled ? 1 : 0),
);
