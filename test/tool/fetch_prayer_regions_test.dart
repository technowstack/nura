import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_region.dart';

import '../../tool/fetch_prayer_regions.dart';

void main() {
  late Directory tmp;
  late File out;
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('fetch_regions');
    out = File('${tmp.path}/prayer_regions.json');
  });
  tearDown(() => tmp.deleteSync(recursive: true));

  Future<int> run(List<String> provinces, Map<String, List<String>> kab) =>
      fetchPrayerRegions(
        fetch: (p) async => p == null ? provinces : (kab[p] ?? <String>[]),
        out: out,
        delay: Duration.zero,
        now: DateTime.utc(2026, 11, 15),
      );

  test('writes names untouched with fetched_at', () async {
    final code = await run(
      ['DKI Jakarta', 'Bali'],
      {
        'DKI Jakarta': [' Kota Jakarta', 'Kab. Kepulauan Seribu'],
        'Bali': ['Kota Denpasar'],
      },
    );
    expect(code, 0);
    final j = jsonDecode(out.readAsStringSync()) as Map<String, dynamic>;
    expect(j['fetched_at'], '2026-11-15T00:00:00.000Z');
    final regions = j['regions'] as Map<String, dynamic>;
    expect(regions['DKI Jakarta'], [' Kota Jakarta', 'Kab. Kepulauan Seribu']);
    expect(regions.keys, ['DKI Jakarta', 'Bali']);
  });

  test('fails when a province has no zone', () async {
    final code = await run(
      ['Papua Selatan'],
      {
        'Papua Selatan': ['Kab. X'],
      },
    );
    expect(code, 1);
    expect(out.existsSync(), isFalse);
    expect(zoneOfProvince('Papua Selatan'), isNull);
  });

  test('fails when a province returns 0 regions', () async {
    final code = await run(['Bali'], {});
    expect(code, 1);
    expect(out.existsSync(), isFalse);
  });
}
