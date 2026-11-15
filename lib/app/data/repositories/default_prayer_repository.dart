import '../../core/prayer_clock.dart';
import '../../services/online_service.dart';
import '../models/prayer_day.dart';
import '../models/prayer_region.dart';
import '../sources/prayer_api_client.dart';
import '../sources/prayer_api_exception.dart';
import '../sources/prayer_calculator.dart';
import '../sources/region_coordinates.dart';
import 'prayer_repository.dart';
import 'prayer_store.dart';

const _noneRetryMs = 24 * 60 * 60 * 1000;

class DefaultPrayerRepository implements PrayerRepository {
  DefaultPrayerRepository({
    required PrayerStore store,
    required PrayerApiClient api,
    required OnlineService online,
    required PrayerClock clock,
    required PrayerCalculator calculator,
    required RegionCoordinates coordinates,
  }) : _store = store,
       _api = api,
       _online = online,
       _clock = clock,
       _calc = calculator,
       _coords = coordinates;

  final PrayerStore _store;
  final PrayerApiClient _api;
  final OnlineService _online;
  final PrayerClock _clock;
  final PrayerCalculator _calc;
  final RegionCoordinates _coords;

  final _unknown = <String>{};
  final _inflight = <String, Future<PrayerApiException?>>{};

  @override
  PrayerRegion? get region => _store.getLocation();

  @override
  bool get syncEnabled => _online.prayerSyncEnabled;

  @override
  void selectRegion(PrayerRegion r) {
    _unknown.clear();
    _store.setLocation(r, source: 'city');
  }

  int get _nowMs => _clock.nowUtc().millisecondsSinceEpoch;

  bool _noneFresh(PrayerRegion r, int y, int m) {
    final rec = _store.getMonth(r, y, m);
    return rec != null &&
        rec.status == MonthStatus.none &&
        _nowMs - rec.fetchedAt < _noneRetryMs;
  }

  @override
  Future<DayResult> dayFor(String date) async {
    final r = _store.getLocation();
    if (r == null) return const DayResult(DayOutcome.noRegion);
    if (_unknown.contains(r.key)) {
      return const DayResult(DayOutcome.unknownRegion);
    }
    final cached = _store.getDay(date, r);
    if (cached != null && cached.source == PrayerSource.api) {
      return DayResult(DayOutcome.api, cached);
    }
    final y = int.parse(date.substring(0, 4));
    final m = int.parse(date.substring(5, 7));
    if (_noneFresh(r, y, m)) return const DayResult(DayOutcome.noData);
    if (_online.prayerSyncEnabled && await _online.canReach()) {
      // Another call may have filled the cache while we awaited the probe.
      final again = _store.getDay(date, r);
      if (again != null && again.source == PrayerSource.api) {
        return DayResult(DayOutcome.api, again);
      }
      if (_noneFresh(r, y, m)) return const DayResult(DayOutcome.noData);
      final err = await _fetch(r, y, m);
      if (err is UnknownRegion) {
        return const DayResult(DayOutcome.unknownRegion);
      }
      if (err is NoDataForMonth) return const DayResult(DayOutcome.noData);
      final fresh = _store.getDay(date, r);
      if (err == null && fresh != null) {
        return DayResult(DayOutcome.api, fresh);
      }
    }
    final at = _coords.of(r);
    if (at == null) return const DayResult(DayOutcome.needsInternet);
    final d = _calc.calculate(r, date, at, _nowMs);
    _store.saveCalcDay(r, d);
    return DayResult(DayOutcome.calc, d);
  }

  /// Single-flight per region+month; the error (null on success) is shared.
  Future<PrayerApiException?> _fetch(PrayerRegion r, int y, int m) {
    return _inflight.putIfAbsent('${r.key}|$y-$m', () async {
      try {
        final days = await _api.fetchMonth(r, y, m);
        _store.saveMonth(r, y, m, days);
        return null;
      } on UnknownRegion catch (e) {
        _unknown.add(r.key);
        return e;
      } on NoDataForMonth catch (e) {
        _store.markMonthNone(r, y, m, _nowMs);
        return e;
      } on PrayerApiException catch (e) {
        return e;
      } finally {
        // Removed after completion so later calls can retry.
        _inflight.remove('${r.key}|$y-$m');
      }
    });
  }

  @override
  Future<void> syncIfNeeded() async {
    final r = _store.getLocation();
    if (r == null || _unknown.contains(r.key)) return;
    if (!_online.prayerSyncEnabled || !await _online.canReach()) return;
    final today = _clock.todayIn(r.zone);
    final y = int.parse(today.substring(0, 4));
    final m = int.parse(today.substring(5, 7));
    final next = m == 12 ? (y + 1, 1) : (y, m + 1);
    for (final (yy, mm) in [(y, m), next]) {
      if (_store.getMonth(r, yy, mm)?.status == MonthStatus.ok) continue;
      if (_noneFresh(r, yy, mm)) continue;
      final err = await _fetch(r, yy, mm);
      if (err != null && err is! NoDataForMonth) return;
    }
  }
}
