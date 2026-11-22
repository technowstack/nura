import 'dart:async';

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:super_sliver_list/super_sliver_list.dart';

import '../../data/models/ayah.dart';

/// Debounced last-read saving shared by the surah and juz readers.
class LastReadTracker {
  LastReadTracker(this._save, {required this.debounce});

  final void Function(AyahRef) _save;
  final Duration debounce;

  Timer? _timer;
  AyahRef? _pending;
  AyahRef? _saved;
  // Ignore list reports until the user scrolls, so merely opening a
  // reader never overwrites the stored last read.
  bool _tracking = false;

  AyahRef? get pending => _pending;

  /// Marks [ref] as already stored so it is not written again.
  void markSaved(AyahRef ref) => _saved = ref;

  /// Handles a list layout notice. [refAt] maps the first visible item index
  /// to the ayah it stands for (null: nothing to report).
  void onVisibleRange(
    ListController list,
    ScrollController scroll,
    AyahRef? Function(int firstIndex) refAt,
  ) {
    final range = list.visibleRange;
    // Layout notices also fire without user input (item measuring); only
    // start tracking once the user scrolls. jumpTo leaves it idle.
    if (!_tracking &&
        scroll.hasClients &&
        scroll.position.userScrollDirection != ScrollDirection.idle) {
      _tracking = true;
    }
    if (!_tracking || range == null) return;
    final ref = refAt(range.$1);
    // Relayouts re-notify with the same range; don't restart the debounce.
    if (ref != null && ref != _pending) report(ref);
  }

  void report(AyahRef ref) {
    _pending = ref;
    _timer?.cancel();
    _timer = Timer(debounce, flush);
  }

  void flush() {
    _timer?.cancel();
    _timer = null;
    final p = _pending;
    if (p == null || p == _saved) return;
    try {
      _save(p);
      _saved = p;
    } on Object catch (e) {
      debugPrint('LastReadTracker: save last read failed: $e');
    }
  }
}
