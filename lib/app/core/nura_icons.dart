import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// Icon constants. Use only the rounded Symbols constants (not the generated
/// lookup maps) so release builds can tree-shake the font.
abstract final class NuraIcons {
  static const IconData refresh = Symbols.refresh_rounded;
  static const IconData brightnessLow = Symbols.brightness_low_rounded;
  static const IconData tune = Symbols.tune_rounded;
  static const IconData check = Symbols.check_rounded;
  static const IconData arrowBack = Symbols.arrow_back_rounded;
  static const IconData arrowForward = Symbols.arrow_forward_rounded;
  static const IconData playArrow = Symbols.play_arrow_rounded;
  static const IconData pause = Symbols.pause_rounded;
  static const IconData bookmark = Symbols.bookmark_rounded;
  static const IconData menuBook = Symbols.menu_book_rounded;
  static const IconData contentCopy = Symbols.content_copy_rounded;
  static const IconData history = Symbols.history_rounded;
  static const IconData radioChecked = Symbols.radio_button_checked_rounded;
  static const IconData radioUnchecked = Symbols.radio_button_unchecked_rounded;
  static const IconData search = Symbols.search_rounded;
  static const IconData home = Symbols.home_rounded;
  static const IconData autoStories = Symbols.auto_stories_rounded;
  static const IconData schedule = Symbols.schedule_rounded;
  static const IconData chevronRight = Symbols.chevron_right_rounded;
  static const IconData close = Symbols.close_rounded;
  static const IconData locationOn = Symbols.location_on_rounded;
  static const IconData bedtime = Symbols.bedtime_rounded;
  static const IconData twilight = Symbols.wb_twilight_rounded;
  static const IconData sunny = Symbols.wb_sunny_rounded;
  static const IconData moreHoriz = Symbols.more_horiz_rounded;
}

/// Material Symbols icon at weight 300; [filled] drives the fill axis.
/// [size] and [color] stay null by default so IconTheme still applies.
class NuraIcon extends StatelessWidget {
  const NuraIcon(
    this.icon, {
    super.key,
    this.size,
    this.color,
    this.filled = false,
    this.semanticLabel,
  });

  final IconData icon;
  final double? size;
  final Color? color;
  final bool filled;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) => Icon(
    icon,
    size: size,
    color: color,
    weight: 300,
    fill: filled ? 1 : 0,
    semanticLabel: semanticLabel,
  );
}
