import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:home_widget/home_widget.dart';

import '../core/daily_link.dart';
import '../modules/hadith_detail/hadith_detail_args.dart';
import '../modules/quran_detail/surah_args.dart';
import '../modules/shell/controllers/shell_controller.dart';
import '../routes/app_routes.dart';
import 'daily_notifier.dart';

typedef DailyOpen = void Function(String route, Object arguments);

/// Opens the screen behind a widget deep link and brings notification taps to
/// Beranda. Navigation is injectable; [DailyLinkRouter.platform] wires GetX
/// and `home_widget`.
class DailyLinkRouter {
  DailyLinkRouter({
    required DailyOpen open,
    required VoidCallback goHome,
    required Stream<Uri?> clicks,
    required Future<Uri?> Function() initialLink,
  }) : _open = open,
       _goHome = goHome,
       _clicks = clicks,
       _initialLink = initialLink;

  factory DailyLinkRouter.platform() => DailyLinkRouter(
    open: (route, args) => unawaited(Get.toNamed<void>(route, arguments: args)),
    goHome: _homeViaGet,
    clicks: HomeWidget.widgetClicked,
    initialLink: HomeWidget.initiallyLaunchedFromHomeWidget,
  );

  final DailyOpen _open;
  final VoidCallback _goHome;
  final Stream<Uri?> _clicks;
  final Future<Uri?> Function() _initialLink;
  StreamSubscription<Uri?>? _sub;

  static void _homeViaGet() {
    if (Get.isRegistered<ShellController>()) {
      Get.find<ShellController>().select(0);
    }
    try {
      Get.until((route) => route.isFirst);
    } on Object catch (e) {
      debugPrint('DailyLinkRouter: cannot pop to root: $e');
    }
  }

  /// Subscribes early; the cold-start link waits for the first frame so the
  /// navigator exists.
  void start() {
    _sub ??= _clicks.listen((u) => handle(u?.toString()));
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        handle((await _initialLink())?.toString());
      } on Object catch (e) {
        debugPrint('DailyLinkRouter: initial link failed: $e');
      }
    });
  }

  void dispose() {
    unawaited(_sub?.cancel());
    _sub = null;
  }

  /// Anything null, empty or unparseable just leaves the app open.
  void handle(String? link) {
    if (link == null || link.isEmpty) return;
    switch (parseDailyLink(link)) {
      case AyahLink(:final surah, :final ayah):
        _open(Routes.surah, SurahArgs(surah, ayah));
      case HadithLink(:final slug, :final number):
        _open(Routes.hadithDetail, HadithDetailArgs(slug, number));
      case null:
        break;
    }
  }

  void onNotificationTap(String? payload) {
    if (payload == dailyPayload) _goHome();
  }
}
