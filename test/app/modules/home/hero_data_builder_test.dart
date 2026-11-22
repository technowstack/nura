import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_day.dart';
import 'package:nura/app/modules/home/hero_data_builder.dart';
import 'package:nura/app/modules/home/widgets/home_hero_data.dart';

PrayerDay day(
  String date, {
  PrayerSource source = PrayerSource.api,
  String? subuh = '04:30',
  String? maghrib = '18:00',
}) => PrayerDay(
  date: date,
  subuh: subuh,
  terbit: '05:40',
  dzuhur: '11:50',
  ashar: '15:10',
  maghrib: maghrib,
  isya: '19:10',
  source: source,
  fetchedAt: 1,
);

HomeHeroData build(
  DateTime now, {
  PrayerDay? today,
  PrayerDay? tomorrow,
  String? region = 'Kota Bandung',
}) => buildHeroData(
  today: today ?? day('2026-11-19'),
  tomorrow: tomorrow,
  now: now,
  regionLabel: region,
  hijri: '1 Jumadil Awal 1448',
);

void main() {
  test('six times in order with the next one before Subuh', () {
    final h = build(DateTime(2026, 11, 19, 3));
    expect(h.times.map((t) => t.name), [
      'Subuh',
      'Terbit',
      'Dzuhur',
      'Ashar',
      'Maghrib',
      'Isya',
    ]);
    expect(h.times.first.time, '04:30');
    expect(h.nextIndex, 0);
    expect(h.countdownText, 'Subuh dalam 1 jam 30 menit');
    expect(h.clock, '03:00');
    expect(h.approximate, isFalse);
  });

  test('between times', () {
    final h = build(DateTime(2026, 11, 19, 17, 33));
    expect(h.nextIndex, 4);
    expect(h.countdownText, 'Maghrib dalam 27 menit');
  });

  test('exactly at a time it counts as passed', () {
    final h = build(DateTime(2026, 11, 19, 18));
    expect(h.nextIndex, 5);
    expect(h.countdownText, 'Isya dalam 1 jam 10 menit');
  });

  test('hour wording', () {
    expect(
      build(DateTime(2026, 11, 19, 16, 55)).countdownText,
      'Maghrib dalam 1 jam 5 menit',
    );
    expect(
      build(DateTime(2026, 11, 19, 16)).countdownText,
      'Maghrib dalam 2 jam',
    );
  });

  test('under a minute', () {
    final h = build(DateTime(2026, 11, 19, 17, 59, 1));
    expect(h.countdownText, 'Maghrib dalam kurang dari 1 menit');
    expect(
      build(DateTime(2026, 11, 19, 17, 58, 30)).countdownText,
      'Maghrib dalam 1 menit',
    );
  });

  test('after Isya points to tomorrow Subuh', () {
    final h = build(
      DateTime(2026, 11, 19, 21),
      tomorrow: day('2026-11-20', subuh: '04:29'),
    );
    expect(h.nextIndex, 0);
    expect(h.countdownText, 'Subuh dalam 7 jam 29 menit');
  });

  test('after Isya without tomorrow: no countdown, no invented time', () {
    final h = build(DateTime(2026, 11, 19, 21));
    expect(h.nextIndex, isNull);
    expect(h.countdownText, isNull);
    expect(h.times, hasLength(6));
  });

  test('tomorrow with a wrong date is ignored', () {
    final h = build(DateTime(2026, 11, 19, 21), tomorrow: day('2026-11-25'));
    expect(h.countdownText, isNull);
  });

  test('month end: tomorrow is the 1st of the next month', () {
    final h = buildHeroData(
      today: day('2026-11-30'),
      tomorrow: day('2026-12-01'),
      now: DateTime(2026, 11, 30, 23),
      regionLabel: 'X',
      hijri: '',
    );
    expect(h.countdownText, startsWith('Subuh dalam'));
  });

  test('no region: label and prompt, no times', () {
    final h = buildHeroData(
      today: null,
      tomorrow: null,
      now: DateTime(2026, 11, 19, 9),
      regionLabel: null,
      hijri: 'h',
    );
    expect(h.locationLabel, 'Pilih wilayah');
    expect(h.emptyText, 'Pilih wilayah untuk melihat jadwal sholat');
    expect(h.times, isEmpty);
    expect(h.countdownText, isNull);
    expect(h.clock, '09:00');
  });

  test('region set but no schedule', () {
    final h = buildHeroData(
      today: null,
      tomorrow: null,
      now: DateTime(2026, 11, 19, 9),
      regionLabel: 'Kota Bandung',
      hijri: '',
    );
    expect(h.locationLabel, 'Kota Bandung');
    expect(h.emptyText, 'Jadwal belum tersedia');
    expect(h.times, isEmpty);
  });

  test('a day with every time missing is empty', () {
    final empty = PrayerDay(
      date: '2026-11-19',
      source: PrayerSource.api,
      fetchedAt: 1,
    );
    expect(build(DateTime(2026, 11, 19, 9), today: empty).times, isEmpty);
  });

  test('a missing time shows --:-- and is skipped as next', () {
    final h = build(
      DateTime(2026, 11, 19, 12),
      today: day('2026-11-19', maghrib: null),
    );
    expect(h.times[4].time, '--:--');
    expect(h.nextIndex, 3);
  });

  test('calculated source is approximate', () {
    final h = build(
      DateTime(2026, 11, 19, 9),
      today: day('2026-11-19', source: PrayerSource.calc),
    );
    expect(h.approximate, isTrue);
  });

  test('midnight rollover: yesterday data is stale, new day data works', () {
    final stale = build(
      DateTime(2026, 11, 20, 0, 0, 30),
      today: day('2026-11-19'),
    );
    expect(stale.times, isEmpty);
    final fresh = build(
      DateTime(2026, 11, 20, 0, 0, 30),
      today: day('2026-11-20'),
    );
    expect(fresh.nextIndex, 0);
    expect(fresh.clock, '00:00');
  });

  test('Terbit is never the next prayer', () {
    for (final t in [
      DateTime(2026, 11, 19, 5),
      DateTime(2026, 11, 19, 5, 50),
    ]) {
      final h = build(t);
      expect(h.nextIndex, 2);
      expect(h.countdownText, startsWith('Dzuhur dalam'));
      expect(h.times[1].name, 'Terbit');
    }
  });

  test('exactly at Isya the next is tomorrow Subuh', () {
    final h = build(
      DateTime(2026, 11, 19, 19, 10),
      tomorrow: day('2026-11-20', subuh: '04:29'),
    );
    expect(h.nextIndex, 0);
    expect(h.countdownText, 'Subuh dalam 9 jam 19 menit');
  });
}
