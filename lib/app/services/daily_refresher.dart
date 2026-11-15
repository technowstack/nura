import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Keeps the daily widget images and notifications current: runs both after
/// the first frame, on resume, on date change and on setting changes.
///
/// Runs are serialized and never throw. A run is skipped when the local date
/// equals the date of the last successful run, unless forced.
class DailyRefresher with WidgetsBindingObserver {
  DailyRefresher({
    required Future<bool> Function() renderWidgets,
    required Future<void> Function() reschedule,
    required DateTime Function() now,
  }) : _renderWidgets = renderWidgets,
       _reschedule = reschedule,
       _now = now;

  final Future<bool> Function() _renderWidgets;
  final Future<void> Function() _reschedule;
  final DateTime Function() _now;

  Future<void> _inFlight = Future<void>.value();
  DateTime? _lastOk;

  /// Never delays the first frame: the first run starts after it.
  void start() {
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => unawaited(refresh()));
  }

  void dispose() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh({bool force = false}) {
    final run = _inFlight.then((_) => _run(force));
    _inFlight = run;
    return run;
  }

  Future<void> _run(bool force) async {
    final n = _now();
    final today = DateTime(n.year, n.month, n.day);
    if (!force && _lastOk == today) return;
    final watch = Stopwatch()..start();
    var ok = true;
    try {
      // False = some entry failed; the run is retried by the next trigger.
      if (!await _renderWidgets()) ok = false;
    } on Object catch (e) {
      ok = false;
      debugPrint('DailyRefresher: widgets failed: $e');
    }
    // Lets frames and input run between the two heavy phases.
    await Future<void>.delayed(Duration.zero);
    try {
      await _reschedule();
    } on Object catch (e) {
      ok = false;
      debugPrint('DailyRefresher: notifications failed: $e');
    }
    if (ok) _lastOk = today;
    if (kDebugMode) debugPrint('daily refresh ${watch.elapsedMilliseconds} ms');
  }
}
