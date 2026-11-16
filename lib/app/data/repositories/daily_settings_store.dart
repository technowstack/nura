import '../models/daily_content.dart';

/// Local settings for the daily ayah/hadith feature.
abstract interface class DailySettingsStore {
  HadithSource get hadithSource;
  void setHadithSource(HadithSource s);
  bool get notifyEnabled;
  void setNotifyEnabled(bool v);

  /// `HH:mm`, default `06:00`.
  String get notifyTime;

  /// Throws [ArgumentError] unless [t] is a valid `HH:mm`.
  void setNotifyTime(String t);
}
