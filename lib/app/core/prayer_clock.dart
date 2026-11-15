import '../data/models/prayer_region.dart';

/// Time helpers that use the region's fixed UTC offset, never the device zone.
class PrayerClock {
  const PrayerClock();

  DateTime nowUtc() => DateTime.now().toUtc();

  /// Region-local date (yyyy-MM-dd) of the current instant.
  String todayIn(PrayerZone z) {
    final t = nowUtc().add(Duration(hours: z.offsetHours));
    return '${t.year.toString().padLeft(4, '0')}-'
        '${t.month.toString().padLeft(2, '0')}-'
        '${t.day.toString().padLeft(2, '0')}';
  }

  /// Absolute UTC instant of region-local [date] (yyyy-MM-dd) at [hhmm].
  DateTime instantOf(String date, String hhmm, PrayerZone z) {
    final d = date.split('-').map(int.parse).toList();
    final t = hhmm.split(':').map(int.parse).toList();
    return DateTime.utc(
      d[0],
      d[1],
      d[2],
      t[0],
      t[1],
    ).subtract(Duration(hours: z.offsetHours));
  }
}
