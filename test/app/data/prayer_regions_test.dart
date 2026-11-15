import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_region.dart';
import 'package:nura/app/data/sources/prayer_regions_source.dart';

class _Bundle extends CachingAssetBundle {
  _Bundle(this.json);
  final String json;
  @override
  Future<ByteData> load(String key) async {
    final b = utf8.encode(json);
    return ByteData.sublistView(Uint8List.fromList(b));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('zoneOfProvince maps known provinces', () {
    expect(zoneOfProvince('DKI Jakarta'), PrayerZone.wib);
    expect(zoneOfProvince('Kalimantan Timur'), PrayerZone.wita);
    expect(zoneOfProvince('Papua Barat'), PrayerZone.wit);
    expect(zoneOfProvince('Papua Selatan'), isNull);
    expect(PrayerZone.wita.offsetHours, 8);
    expect(PrayerZone.wit.label, 'WIT');
  });

  test(
    'real snapshot: every province has a zone, search and find work',
    () async {
      final r = await loadPrayerRegions(rootBundle);
      expect(r.provinces.length, 34);
      for (final p in r.provinces) {
        expect(zoneOfProvince(p), isNotNull, reason: p);
      }
      expect(
        r.search('JAKARTA').any((x) => x.kabkota == 'Kota Jakarta'),
        isTrue,
      );
      expect(
        r.search('seribu').any((x) => x.kabkota == 'Kab. Kepulauan Seribu'),
        isTrue,
      );
      expect(r.find('DKI Jakarta', 'Tidak Ada'), isNull);
      final f = r.find('DKI Jakarta', 'Kota Jakarta');
      expect(f?.zone, PrayerZone.wib);
      expect(f?.key, 'DKI Jakarta|Kota Jakarta');
      expect(r.kabkotaOf('Nope'), isEmpty);
    },
  );

  test('loadPrayerRegions parses a bundle', () async {
    final r = await loadPrayerRegions(
      _Bundle('{"fetched_at":"x","regions":{"Bali":["Kota Denpasar"]}}'),
    );
    expect(r.provinces, ['Bali']);
    expect(r.kabkotaOf('Bali'), ['Kota Denpasar']);
    expect(r.find('Bali', 'Kota Denpasar')?.zone, PrayerZone.wita);
  });
}
