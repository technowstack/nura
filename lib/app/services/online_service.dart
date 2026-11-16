import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../data/sources/setting_keys.dart';
import '../data/sources/user_database.dart';

/// Whether the device looks connected; only a hint, requests can still fail.
Future<bool> connectivityProbe() async {
  final r = await Connectivity().checkConnectivity();
  return r.any((c) => c != ConnectivityResult.none);
}

/// Gate for the optional online features.
class OnlineService {
  OnlineService(this._db, {Future<bool> Function()? probe})
    : _probe = probe ?? connectivityProbe;

  final UserDatabase _db;
  final Future<bool> Function() _probe;

  bool get prayerSyncEnabled =>
      _db.getSetting(SettingKeys.prayerSyncEnabled) == 'true';

  void setPrayerSyncEnabled(bool v) =>
      _db.setSetting(SettingKeys.prayerSyncEnabled, v ? 'true' : 'false');

  final _audioChanges = StreamController<bool>.broadcast();

  /// Audio streaming switch (`online_enabled`); off by default.
  bool get audioEnabled => _db.getSetting(SettingKeys.onlineEnabled) == 'true';

  /// Emits the new value once per actual change of [audioEnabled].
  Stream<bool> get audioEnabledChanges => _audioChanges.stream;

  void setAudioEnabled(bool v) {
    if (v == audioEnabled) return;
    _db.setSetting(SettingKeys.onlineEnabled, v ? 'true' : 'false');
    _audioChanges.add(v);
  }

  Future<bool> canReach() async {
    try {
      return await _probe();
    } catch (_) {
      return false;
    }
  }
}
