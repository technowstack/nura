import '../models/daily_content.dart';
import '../sources/setting_keys.dart';
import '../sources/user_database.dart';
import 'daily_settings_store.dart';

class SqliteDailySettingsStore implements DailySettingsStore {
  SqliteDailySettingsStore(this._db);

  static const _defaultTime = '06:00';
  static final _timePattern = RegExp(r'^([01]\d|2[0-3]):[0-5]\d$');

  final UserDatabase _db;

  @override
  HadithSource get hadithSource {
    final v = _db.getSetting(SettingKeys.dailyHadithSource);
    return HadithSource.values.where((s) => s.value == v).firstOrNull ??
        HadithSource.defaultBm;
  }

  @override
  void setHadithSource(HadithSource s) =>
      _db.setSetting(SettingKeys.dailyHadithSource, s.value);

  @override
  bool get notifyEnabled =>
      _db.getSetting(SettingKeys.dailyNotifyEnabled) == 'true';

  @override
  void setNotifyEnabled(bool v) =>
      _db.setSetting(SettingKeys.dailyNotifyEnabled, v.toString());

  @override
  String get notifyTime {
    final v = _db.getSetting(SettingKeys.dailyNotifyTime);
    return v != null && _timePattern.hasMatch(v) ? v : _defaultTime;
  }

  @override
  void setNotifyTime(String t) {
    if (!_timePattern.hasMatch(t)) {
      throw ArgumentError.value(t, 't', 'expected HH:mm');
    }
    _db.setSetting(SettingKeys.dailyNotifyTime, t);
  }
}
