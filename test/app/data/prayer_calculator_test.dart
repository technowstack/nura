import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/sources/prayer_calculator.dart';

int _min(String hm) {
  final p = hm.split(':');
  return int.parse(p[0]) * 60 + int.parse(p[1]);
}

const _jakarta = PrayerRegion(
  provinsi: 'DKI Jakarta',
  kabkota: 'Kota Jakarta',
  zone: PrayerZone.wib,
);
const _bontang = PrayerRegion(
  provinsi: 'Kalimantan Timur',
  kabkota: 'Kota Bontang',
  zone: PrayerZone.wita,
);

List<Map<String, dynamic>> _fixture(String name) {
  final j =
      jsonDecode(File('test/fixtures/prayer/$name').readAsStringSync())
          as Map<String, dynamic>;
  return ((j['data'] as Map<String, dynamic>)['jadwal'] as List)
      .cast<Map<String, dynamic>>();
}

Map<String, String?> _times(PrayerDay d) => {
  'subuh': d.subuh,
  'terbit': d.terbit,
  'dzuhur': d.dzuhur,
  'ashar': d.ashar,
  'maghrib': d.maghrib,
  'isya': d.isya,
};

void main() {
  const calc = AdhanPrayerCalculator();
  final cases = [
    ('jakarta_2026_11.json', _jakarta, (lat: -6.2088, lng: 106.8456)),
    ('bontang_2026_11.json', _bontang, (lat: 0.1333, lng: 117.5)),
  ];

  for (final (file, region, at) in cases) {
    test('$file within 2 minutes of API for every day', () {
      for (final row in _fixture(file)) {
        final date = row['tanggal_lengkap'] as String;
        final d = calc.calculate(region, date, at, 5);
        expect(d.source, PrayerSource.calc);
        expect(d.dhuha, isNull);
        expect(d.fetchedAt, 5);
        expect(_min(d.imsak ?? ''), _min(d.subuh ?? '') - 10);
        _times(d).forEach((k, v) {
          final diff = (_min(v ?? '') - _min(row[k] as String)).abs();
          expect(
            diff,
            lessThanOrEqualTo(2),
            reason: '$date $k $v vs ${row[k]}',
          );
        });
      }
    });
  }

  test(
    'adjustment user adjustment shifts exactly one prayer by 2 minutes beyond built-in',
    () {
      const at = (lat: -6.2088, lng: 106.8456);
      final base = calc.calculate(_jakarta, '2026-11-05', at, 0);
      for (final name in PrayerName.values) {
        final adj = AdhanPrayerCalculator(
          adjustMinutes: () => {name: 2},
        ).calculate(_jakarta, '2026-11-05', at, 0);
        final b = _times(base);
        _times(adj).forEach((k, v) {
          final shifted = k == name.name ? 2 : 0;
          expect(_min(v ?? '') - _min(b[k] ?? ''), shifted, reason: '$name $k');
        });
      }
    },
  );

  test('date is read in region zone, not device zone', () {
    const at = (lat: -6.2088, lng: 106.8456);
    const wit = PrayerRegion(
      provinsi: 'Papua',
      kabkota: 'X',
      zone: PrayerZone.wit,
    );
    final a = _times(calc.calculate(_jakarta, '2026-11-05', at, 0));
    final b = _times(calc.calculate(wit, '2026-11-05', at, 0));
    a.forEach((k, v) {
      expect(_min(b[k] ?? '') - _min(v ?? ''), 120, reason: k);
    });
  });
}
