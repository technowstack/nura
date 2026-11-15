import '../models/prayer_day.dart';
import '../models/prayer_region.dart';

enum DayOutcome { api, calc, needsInternet, unknownRegion, noRegion, noData }

class DayResult {
  const DayResult(this.outcome, [this.day]);

  final DayOutcome outcome;
  final PrayerDay? day;
}

abstract interface class PrayerRepository {
  PrayerRegion? get region;
  bool get syncEnabled;

  /// Persists [r] and clears the unknown-region mark.
  void selectRegion(PrayerRegion r);

  /// [date] is yyyy-MM-dd in the region's zone.
  Future<DayResult> dayFor(String date);

  /// Fetches the current and next month when missing; no-op unless sync is on
  /// and reachable.
  Future<void> syncIfNeeded();
}
