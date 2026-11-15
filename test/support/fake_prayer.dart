import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/core/prayer_clock.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/sources/prayer_api_client.dart';
import 'package:nura/app/data/sources/prayer_calculator.dart';
import 'package:nura/app/data/sources/region_coordinates.dart';

class FakeClock extends PrayerClock {
  FakeClock(this.now);

  DateTime now;

  @override
  DateTime nowUtc() => now;
}

/// Fake API: [handler] answers each call (throw to simulate failures).
class FakePrayerApi implements PrayerApiClient {
  FakePrayerApi(this.handler);

  Future<List<PrayerDay>> Function(PrayerRegion r, int y, int m) handler;
  final calls = <String>[];

  @override
  Future<List<PrayerDay>> fetchMonth(PrayerRegion r, int y, int m) {
    calls.add('$y-${m.toString().padLeft(2, '0')}');
    return handler(r, y, m);
  }
}

List<PrayerDay> monthDays(int y, int m, {int fetchedAt = 1}) {
  final n = DateTime(y, m + 1, 0).day;
  return [
    for (var d = 1; d <= n; d++)
      PrayerDay(
        date:
            '$y-${m.toString().padLeft(2, '0')}-${d.toString().padLeft(2, '0')}',
        subuh: '04:30',
        source: PrayerSource.api,
        fetchedAt: fetchedAt,
      ),
  ];
}

class FixedCoordinates implements RegionCoordinates {
  @override
  ({double lat, double lng})? of(PrayerRegion r) => (lat: -6.2, lng: 106.8);
}

class FakeCalculator implements PrayerCalculator {
  @override
  PrayerDay calculate(
    PrayerRegion r,
    String date,
    ({double lat, double lng}) at,
    int fetchedAt,
  ) => PrayerDay(
    date: date,
    subuh: '04:31',
    source: PrayerSource.calc,
    fetchedAt: fetchedAt,
  );
}

/// Fake repository: [days] answers `dayFor` by date; unknown dates are noData.
class FakePrayerRepository implements PrayerRepository {
  FakePrayerRepository({
    this.region,
    this.syncEnabled = false,
    Map<String, DayResult>? days,
  }) : days = days ?? {};

  @override
  PrayerRegion? region;
  @override
  bool syncEnabled;
  final Map<String, DayResult> days;
  final calls = <String>[];
  Object? failWith;

  @override
  void selectRegion(PrayerRegion r) {
    calls.add('select:${r.key}');
    region = r;
  }

  @override
  Future<DayResult> dayFor(String date) async {
    calls.add('day:$date');
    if (failWith case final e?) throw e;
    return days[date] ?? const DayResult(DayOutcome.noData);
  }

  @override
  Future<void> syncIfNeeded() async => calls.add('sync');
}

PrayerDay fullDay(
  String date, {
  PrayerSource source = PrayerSource.api,
  String? dhuha = '05:50',
}) => PrayerDay(
  date: date,
  imsak: '04:20',
  subuh: '04:30',
  terbit: '05:40',
  dhuha: dhuha,
  dzuhur: '11:50',
  ashar: '15:10',
  maghrib: '18:00',
  isya: '19:10',
  source: source,
  fetchedAt: 1,
);
