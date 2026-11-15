import '../models/prayer_day.dart';
import '../models/prayer_region.dart';

/// Offline prayer time calculation for one region-local [date].
abstract interface class PrayerCalculator {
  PrayerDay calculate(
    PrayerRegion r,
    String date,
    ({double lat, double lng}) at,
    int fetchedAt,
  );
}
