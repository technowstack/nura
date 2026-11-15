import 'package:adhan/adhan.dart';

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

/// Built-in ihtiyat (safety margin) in minutes, measured against the
/// equran.id (Kemenag) times for Nov 2026 Jakarta and Bontang (owner
/// decision Q5, 2026-11-15). Prayers get +3, sunrise gets -3.
/// Dzuhur note: adhan's Singapore method already adds +1 to dzuhur
/// (methodAdjustments, summed separately), so the effective dzuhur ihtiyat
/// relative to astronomical time is +4, not +3.
const kIhtiyatMinutes = (prayer: 3, terbit: -3);

/// Offline calculation with the Singapore method (Fajr 20, Isha 18),
/// Shafi'i Asr. The `adhan` package rounds each time to the nearest minute.
/// Times are read as UTC with the region's fixed zone offset applied, so the
/// device time zone is never involved. `dhuha` is null (rule not settled).
class AdhanPrayerCalculator implements PrayerCalculator {
  const AdhanPrayerCalculator({this.adjustMinutes});

  /// Per-prayer user fine-tune in minutes, added on top of [kIhtiyatMinutes];
  /// missing names mean 0.
  final Map<PrayerName, int> Function()? adjustMinutes;

  @override
  PrayerDay calculate(
    PrayerRegion r,
    String date,
    ({double lat, double lng}) at,
    int fetchedAt,
  ) {
    final parts = date.split('-').map(int.parse).toList();
    final adj = adjustMinutes?.call() ?? const <PrayerName, int>{};
    final params = CalculationMethod.singapore.getParameters()
      ..madhab = Madhab.shafi
      ..adjustments.fajr = kIhtiyatMinutes.prayer + (adj[PrayerName.subuh] ?? 0)
      ..adjustments.sunrise = kIhtiyatMinutes.terbit
      ..adjustments.dhuhr =
          kIhtiyatMinutes.prayer + (adj[PrayerName.dzuhur] ?? 0)
      ..adjustments.asr = kIhtiyatMinutes.prayer + (adj[PrayerName.ashar] ?? 0)
      ..adjustments.maghrib =
          kIhtiyatMinutes.prayer + (adj[PrayerName.maghrib] ?? 0)
      ..adjustments.isha = kIhtiyatMinutes.prayer + (adj[PrayerName.isya] ?? 0);
    final t = PrayerTimes(
      Coordinates(at.lat, at.lng),
      DateComponents(parts[0], parts[1], parts[2]),
      params,
      utcOffset: Duration(hours: r.zone.offsetHours),
    );
    return PrayerDay(
      date: date,
      imsak: _hm(t.fajr.subtract(const Duration(minutes: 10))),
      subuh: _hm(t.fajr),
      terbit: _hm(t.sunrise),
      dzuhur: _hm(t.dhuhr),
      ashar: _hm(t.asr),
      maghrib: _hm(t.maghrib),
      isya: _hm(t.isha),
      source: PrayerSource.calc,
      fetchedAt: fetchedAt,
    );
  }

  static String _hm(DateTime d) =>
      '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';
}
