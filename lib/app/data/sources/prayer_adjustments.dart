import '../models/prayer_day.dart';
import 'setting_keys.dart';
import 'user_database.dart';

/// Reads the user's per-prayer minute adjustments at call time (default 0,
/// unparseable values count as 0).
Map<PrayerName, int> Function() prayerAdjustmentsFrom(UserDatabase db) {
  int read(String key) => int.tryParse(db.getSetting(key) ?? '') ?? 0;
  return () => {
    PrayerName.subuh: read(SettingKeys.prayerAdjustFajr),
    PrayerName.dzuhur: read(SettingKeys.prayerAdjustDhuhr),
    PrayerName.ashar: read(SettingKeys.prayerAdjustAsr),
    PrayerName.maghrib: read(SettingKeys.prayerAdjustMaghrib),
    PrayerName.isya: read(SettingKeys.prayerAdjustIsha),
  };
}
