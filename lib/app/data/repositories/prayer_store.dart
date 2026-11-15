import '../models/prayer_day.dart';
import '../models/prayer_region.dart';

/// Local storage for the chosen prayer region and cached prayer times.
abstract interface class PrayerStore {
  /// Null when unset or when the stored province has no known zone.
  PrayerRegion? getLocation();
  void setLocation(PrayerRegion r, {required String source});
  PrayerDay? getDay(String date, PrayerRegion r);

  /// Upserts the dates present in [days] (replacing any day, `api` or `calc`,
  /// on those dates; other dates are untouched) and marks the month `ok`,
  /// atomically.
  /// The month `fetched_at` is taken from the first day, so the caller must
  /// stamp every day of one fetch with the same time. Throws [ArgumentError]
  /// on an empty list; use [markMonthNone] instead.
  void saveMonth(PrayerRegion r, int year, int month, List<PrayerDay> days);
  void markMonthNone(PrayerRegion r, int year, int month, int nowMs);
  MonthRecord? getMonth(PrayerRegion r, int year, int month);

  /// Stores a calculated day unless an API day already exists for that date.
  void saveCalcDay(PrayerRegion r, PrayerDay d);

  /// Number of stored `api` days with date >= [date] (yyyy-MM-dd).
  int apiDaysFrom(String date, PrayerRegion r);
  bool notifyEnabled(PrayerName p);
  void setNotifyEnabled(PrayerName p, bool v);
}
