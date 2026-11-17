import 'dart:async';

import 'package:flutter/widgets.dart';

/// Exposes [WidgetsBindingObserver] lifecycle changes as a broadcast stream.
class AppLifecycleStream with WidgetsBindingObserver {
  AppLifecycleStream() {
    WidgetsBinding.instance.addObserver(this);
  }

  final _ctl = StreamController<AppLifecycleState>.broadcast();

  Stream<AppLifecycleState> get stream => _ctl.stream;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) => _ctl.add(state);

  Future<void> close() {
    WidgetsBinding.instance.removeObserver(this);
    return _ctl.close();
  }
}
