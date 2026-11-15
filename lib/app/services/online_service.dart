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

  Future<bool> canReach() => _probe();
}
