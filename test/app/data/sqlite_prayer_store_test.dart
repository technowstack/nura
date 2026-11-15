import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/repositories/sqlite_prayer_store.dart';
import 'package:nura/app/data/sources/user_database.dart';

void main() {
  late Directory tmp;
  late UserDatabase db;
  late SqlitePrayerStore store;

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

  PrayerDay day(
    int d, {
    PrayerSource s = PrayerSource.api,
    String t = '04:30',
  }) => PrayerDay(
    date: '2026-11-${d.toString().padLeft(2, '0')}',
    subuh: t,
    source: s,
    fetchedAt: 100,
  );

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_pstore_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = UserDatabase.open(File('${tmp.path}/user.db'));
    addTearDown(db.close);
    store = SqlitePrayerStore(db);
  });

  test('location round trip, null when unset or zone unknown', () {
    expect(store.getLocation(), isNull);
    store.setLocation(jkt, source: 'city');
    final r = store.getLocation();
    expect(r?.key, jkt.key);
    expect(r?.zone, PrayerZone.wib);
    db.raw.execute("UPDATE prayer_location SET provinsi = 'Papua Selatan'");
    expect(store.getLocation(), isNull);
  });

  test('saveMonth stores 30 days and overwrites calc days of the month', () {
    store.saveCalcDay(jkt, day(5, s: PrayerSource.calc, t: '09:99'));
    store.saveMonth(jkt, 2026, 11, [for (var d = 1; d <= 30; d++) day(d)]);
    expect(store.apiDaysFrom('2026-11-01', jkt), 30);
    expect(store.getDay('2026-11-05', jkt)?.source, PrayerSource.api);
    expect(store.getDay('2026-11-05', jkt)?.subuh, '04:30');
    expect(store.getMonth(jkt, 2026, 11)?.status, MonthStatus.ok);
  });

  test('saveCalcDay does not replace an api day', () {
    store.saveMonth(jkt, 2026, 11, [day(1)]);
    store.saveCalcDay(jkt, day(1, s: PrayerSource.calc, t: '01:00'));
    expect(store.getDay('2026-11-01', jkt)?.subuh, '04:30');
  });

  test('getDay missing is null', () {
    expect(store.getDay('2026-11-01', jkt), isNull);
  });

  test('markMonthNone then getMonth is none', () {
    expect(store.getMonth(jkt, 2026, 12), isNull);
    store.markMonthNone(jkt, 2026, 12, 777);
    final m = store.getMonth(jkt, 2026, 12);
    expect(m?.status, MonthStatus.none);
    expect(m?.fetchedAt, 777);
  });

  const bogor = PrayerRegion(
    provinsi: 'Jawa Barat',
    kabkota: 'Kab. Bogor',
    zone: PrayerZone.wib,
  );
  const bdgSameName = PrayerRegion(
    provinsi: 'Jawa Tengah',
    kabkota: 'Kota Bandung',
    zone: PrayerZone.wib,
  );

  test('regions sharing province or kabkota stay isolated', () {
    store.saveMonth(bdg, 2026, 11, [day(1)]);
    for (final other in [jkt, bogor, bdgSameName]) {
      expect(store.getDay('2026-11-01', other), isNull);
      expect(store.getMonth(other, 2026, 11), isNull);
      expect(store.apiDaysFrom('2026-11-01', other), 0);
    }
    store.saveMonth(bogor, 2026, 11, [day(1), day(2)]);
    store.markMonthNone(bdgSameName, 2026, 11, 5);
    expect(store.apiDaysFrom('2026-11-01', bdg), 1);
    expect(store.apiDaysFrom('2026-11-01', bogor), 2);
    expect(store.getMonth(bdg, 2026, 11)?.status, MonthStatus.ok);
    expect(store.getMonth(bogor, 2026, 11)?.status, MonthStatus.ok);
    expect(store.getMonth(bdgSameName, 2026, 11)?.status, MonthStatus.none);
  });

  test('saveMonth with empty list throws and writes nothing', () {
    expect(() => store.saveMonth(jkt, 2026, 11, []), throwsArgumentError);
    expect(store.getMonth(jkt, 2026, 11), isNull);
  });

  test('apiDaysFrom excludes calc days and honors the lower bound', () {
    store.saveMonth(jkt, 2026, 11, [day(5), day(15), day(25)]);
    store.saveCalcDay(jkt, day(20, s: PrayerSource.calc));
    expect(store.apiDaysFrom('2026-11-01', jkt), 3);
    expect(store.apiDaysFrom('2026-11-15', jkt), 2);
    expect(store.apiDaysFrom('2026-11-16', jkt), 1);
  });

  test('failed saveMonth rolls back days and marker', () {
    final bad = PrayerDay(
      date: '2026-11-02',
      subuh: '04:30',
      source: PrayerSource.api,
      fetchedAt: 100,
    );
    db.raw.execute(
      'CREATE TRIGGER boom BEFORE INSERT ON prayer_day '
      "WHEN NEW.date = '2026-11-02' BEGIN SELECT RAISE(ABORT, 'x'); END",
    );
    expect(
      () => store.saveMonth(jkt, 2026, 11, [day(1), bad]),
      throwsA(anything),
    );
    expect(store.getDay('2026-11-01', jkt), isNull);
    expect(store.getMonth(jkt, 2026, 11), isNull);
  });

  test('notifyEnabled defaults false and round trips', () {
    for (final p in PrayerName.values) {
      expect(store.notifyEnabled(p), isFalse);
    }
    store.setNotifyEnabled(PrayerName.maghrib, true);
    expect(store.notifyEnabled(PrayerName.maghrib), isTrue);
    expect(store.notifyEnabled(PrayerName.isya), isFalse);
    store.setNotifyEnabled(PrayerName.maghrib, false);
    expect(store.notifyEnabled(PrayerName.maghrib), isFalse);
  });
}
