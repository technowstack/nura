enum PrayerName { subuh, dzuhur, ashar, maghrib, isya }

enum PrayerSource { api, calc }

enum MonthStatus { ok, none }

/// One day of prayer times; times are `HH:mm` local to the region.
class PrayerDay {
  const PrayerDay({
    required this.date,
    this.imsak,
    this.subuh,
    this.terbit,
    this.dhuha,
    this.dzuhur,
    this.ashar,
    this.maghrib,
    this.isya,
    required this.source,
    required this.fetchedAt,
  });

  /// yyyy-MM-dd
  final String date;
  final String? imsak, subuh, terbit, dhuha, dzuhur, ashar, maghrib, isya;
  final PrayerSource source;

  /// Epoch milliseconds.
  final int fetchedAt;
}

class MonthRecord {
  const MonthRecord({required this.status, required this.fetchedAt});

  final MonthStatus status;
  final int fetchedAt;
}
