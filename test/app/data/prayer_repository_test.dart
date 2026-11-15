import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/repositories/default_prayer_repository.dart';
import 'package:nura/app/data/repositories/prayer_repository.dart';
import 'package:nura/app/data/repositories/sqlite_prayer_store.dart';
import 'package:nura/app/data/sources/prayer_api_exception.dart';
import 'package:nura/app/data/sources/region_coordinates.dart';
import 'package:nura/app/data/sources/setting_keys.dart';
import 'package:nura/app/data/sources/user_database.dart';
import 'package:nura/app/services/online_service.dart';

import '../../support/fake_prayer.dart';

void main() {
  const jkt = PrayerRegion(
    provinsi: 'DKI Jakarta',
    kabkota: 'Kota Jakarta',
    zone: PrayerZone.wib,
  );
  const bdg = PrayerRegion(
    provinsi: 'Jawa Barat',
    kabkota: 'Kota Bandung',
    zone: PrayerZone.wib,
  );

  late Directory tmp;
  late UserDatabase db;
  late SqlitePrayerStore store;
  late FakeClock clock;
  late FakePrayerApi api;
  late bool reachable;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_prepo_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    store = SqlitePrayerStore(db);
    clock = FakeClock(DateTime.utc(2026, 11, 15, 3));
    reachable = true;
    api = FakePrayerApi((r, y, m) async => monthDays(y, m));
  });

  DefaultPrayerRepository repo({
    bool sync = true,
    RegionCoordinates coords = const NoRegionCoordinates(),
    bool region = true,
  }) {
    if (sync) db.setSetting(SettingKeys.prayerSyncEnabled, 'true');
    final r = DefaultPrayerRepository(
      store: store,
      api: api,
      online: OnlineService(db, probe: () async => reachable),
      clock: clock,
      calculator: FakeCalculator(),
      coordinates: coords,
    );
    if (region) r.selectRegion(jkt);
    return r;
  }

  test('no region selected', () async {
    final res = await repo(region: false).dayFor('2026-11-15');
    expect(res.outcome, DayOutcome.noRegion);
    expect(api.calls, isEmpty);
  });

  test('cached api day makes no network call', () async {
    final r = repo();
    store.saveMonth(jkt, 2026, 11, monthDays(2026, 11));
    final res = await r.dayFor('2026-11-15');
    expect(res.outcome, DayOutcome.api);
    expect(res.day?.date, '2026-11-15');
    expect(api.calls, isEmpty);
  });

  test('sync disabled never calls the API', () async {
    final r = repo(sync: false);
    expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.needsInternet);
    await r.syncIfNeeded();
    expect(api.calls, isEmpty);
  });

  test(
    'sync disabled with coordinates falls back to calc and stores it',
    () async {
      final r = repo(sync: false, coords: FixedCoordinates());
      final res = await r.dayFor('2026-11-15');
      expect(res.outcome, DayOutcome.calc);
      expect(store.getDay('2026-11-15', jkt)?.source, PrayerSource.calc);
    },
  );

  test('unreachable behaves like disabled', () async {
    reachable = false;
    final r = repo();
    expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.needsInternet);
    expect(api.calls, isEmpty);
  });

  test('fetches once, saves, returns api day', () async {
    final r = repo();
    final res = await r.dayFor('2026-11-15');
    expect(res.outcome, DayOutcome.api);
    expect(api.calls, ['2026-11']);
    expect(store.getMonth(jkt, 2026, 11)?.status, MonthStatus.ok);
  });

  test('date absent from fetched month is needsInternet', () async {
    api.handler = (r, y, m) async => monthDays(y, m).take(10).toList();
    final res = await repo().dayFor('2026-11-15');
    expect(res.outcome, DayOutcome.needsInternet);
  });

  test('concurrent dayFor makes one request', () async {
    final r = repo();
    final out = await Future.wait([
      r.dayFor('2026-11-15'),
      r.dayFor('2026-11-16'),
    ]);
    expect(out.map((e) => e.outcome), everyElement(DayOutcome.api));
    expect(api.calls, hasLength(1));
  });

  test('UnknownRegion is not repeated and region is kept', () async {
    api.handler = (r, y, m) async => throw const UnknownRegion();
    final r = repo();
    expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.unknownRegion);
    expect((await r.dayFor('2026-11-16')).outcome, DayOutcome.unknownRegion);
    await r.syncIfNeeded();
    expect(api.calls, hasLength(1));
    expect(store.getLocation()?.key, jkt.key);
    api.handler = (r, y, m) async => monthDays(y, m);
    r.selectRegion(bdg);
    expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.api);
  });

  test('NoDataForMonth cached none for 24 h then retried', () async {
    api.handler = (r, y, m) async => throw const NoDataForMonth();
    final r = repo();
    expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.noData);
    expect(store.getMonth(jkt, 2026, 11)?.status, MonthStatus.none);
    clock.now = clock.now.add(const Duration(hours: 23));
    expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.noData);
    expect(api.calls, hasLength(1));
    clock.now = clock.now.add(const Duration(hours: 2));
    await r.dayFor('2026-11-15');
    expect(api.calls, hasLength(2));
  });

  test(
    'Network without coordinates is needsInternet, retried on sync',
    () async {
      api.handler = (r, y, m) async => throw const Network();
      final r = repo();
      expect((await r.dayFor('2026-11-15')).outcome, DayOutcome.needsInternet);
      await r.syncIfNeeded();
      expect(api.calls, hasLength(2));
    },
  );

  test('BadResponse with coordinates falls back to calc', () async {
    api.handler = (r, y, m) async => throw const BadResponse('x');
    final res = await repo(coords: FixedCoordinates()).dayFor('2026-11-15');
    expect(res.outcome, DayOutcome.calc);
  });

  test('syncIfNeeded fetches current and next month once', () async {
    final r = repo();
    await r.syncIfNeeded();
    await r.syncIfNeeded();
    expect(api.calls, ['2026-11', '2026-12']);
  });

  test('syncIfNeeded rolls December into January of next year', () async {
    clock.now = DateTime.utc(2026, 12, 20);
    final r = repo();
    await r.syncIfNeeded();
    expect(api.calls, ['2026-12', '2027-01']);
  });

  test('syncIfNeeded uses the region zone for the month', () async {
    clock.now = DateTime.utc(2026, 11, 30, 20); // already Dec 1 in WIB
    await repo().syncIfNeeded();
    expect(api.calls, ['2026-12', '2027-01']);
  });

  test('syncIfNeeded does nothing when disabled or unreachable', () async {
    await repo(sync: false).syncIfNeeded();
    expect(api.calls, isEmpty);
    reachable = false;
    await repo().syncIfNeeded();
    expect(api.calls, isEmpty);
  });

  test('reselecting the same region clears the unknown mark', () async {
    api.handler = (r, y, m) async => throw const UnknownRegion();
    final r = repo();
    await r.dayFor('2026-11-15');
    r.selectRegion(jkt);
    await r.dayFor('2026-11-15');
    expect(api.calls, hasLength(2));
  });

  test('syncIfNeeded continues to next month after NoDataForMonth', () async {
    api.handler = (r, y, m) async =>
        m == 11 ? throw const NoDataForMonth() : monthDays(y, m);
    await repo().syncIfNeeded();
    expect(api.calls, ['2026-11', '2026-12']);
  });

  test('syncIfNeeded stops after a network failure', () async {
    api.handler = (r, y, m) async => throw const Network();
    await repo().syncIfNeeded();
    expect(api.calls, ['2026-11']);
  });

  test('re-checks the cache after the reachability probe', () async {
    final probes = <Completer<bool>>[];
    final r = DefaultPrayerRepository(
      store: store,
      api: api,
      online: OnlineService(
        db,
        probe: () {
          final c = Completer<bool>();
          probes.add(c);
          return c.future;
        },
      ),
      clock: clock,
      calculator: FakeCalculator(),
      coordinates: const NoRegionCoordinates(),
    )..selectRegion(jkt);
    db.setSetting(SettingKeys.prayerSyncEnabled, 'true');
    final a = r.dayFor('2026-11-15');
    final b = r.dayFor('2026-11-16');
    await Future<void>.delayed(Duration.zero);
    probes[0].complete(true);
    expect((await a).outcome, DayOutcome.api);
    probes[1].complete(true);
    expect((await b).outcome, DayOutcome.api);
    expect(api.calls, hasLength(1));
  });
}
