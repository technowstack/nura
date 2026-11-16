import '../models/qari.dart';
import '../sources/setting_keys.dart';
import '../sources/user_database.dart';
import 'audio_settings_store.dart';

class SqliteAudioSettingsStore implements AudioSettingsStore {
  SqliteAudioSettingsStore(this._db);

  final UserDatabase _db;

  @override
  String get qariId {
    final v = _db.getSetting(SettingKeys.qariId);
    return v != null && qariById(v) != null ? v : kDefaultQariId;
  }

  @override
  void setQariId(String id) {
    if (qariById(id) == null) {
      throw ArgumentError.value(id, 'id', 'unknown qari');
    }
    _db.setSetting(SettingKeys.qariId, id);
  }
}
