import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/prayer_regions.dart';

export '../models/prayer_regions.dart';

const prayerRegionsAsset = 'data-source/meta/prayer_regions.json';

Future<PrayerRegions> loadPrayerRegions(AssetBundle bundle) async {
  final raw = await bundle.loadString(prayerRegionsAsset);
  final regions = (jsonDecode(raw) as Map<String, dynamic>)['regions'] as Map;
  return PrayerRegions({
    for (final e in regions.entries)
      e.key as String: List<String>.from(e.value as List),
  });
}
