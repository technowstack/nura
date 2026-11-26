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
    Future<String> Function()? widgetState,
    @visibleForTesting Duration Function(DateTime)? utcOffset,
  }) : _widgetState = widgetState,
       _renderWidgets = renderWidgets,
       _reschedule = reschedule,
       _now = now,
       _utcOffset = utcOffset ?? ((d) => d.timeZoneOffset);

  final Future<bool> Function() _renderWidgets;
  final Future<void> Function() _reschedule;
  // Anything besides the date that makes the images outdated (widget sizes).
  final Future<String> Function()? _widgetState;
  final DateTime Function() _now;
  final Duration Function(DateTime) _utcOffset;

  Future<void> _inFlight = Future<void>.value();
  // Local date plus UTC offset, so a time-zone change on the same date reruns.
  String? _lastOk;

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
    var state = '';
    try {
      state = await _widgetState?.call() ?? '';
    } on Object catch (e) {
      debugPrint('DailyRefresher: widget state unreadable: $e');
    }
    final today =
        '${n.year}-${n.month}-${n.day}|${_utcOffset(n).inMinutes}|$state';
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
