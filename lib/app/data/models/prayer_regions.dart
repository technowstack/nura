import 'prayer_region.dart';

class PrayerRegions {
  PrayerRegions(Map<String, List<String>> byProvince)
    : _byProvince = byProvince;

  final Map<String, List<String>> _byProvince;

  List<String> get provinces => _byProvince.keys.toList(growable: false);

  List<String> kabkotaOf(String provinsi) => _byProvince[provinsi] ?? const [];

  /// Case-insensitive match on kab/kota or province name.
  List<PrayerRegion> search(String query) {
    final q = query.trim().toLowerCase();
    return [
      for (final e in _byProvince.entries)
        for (final k in e.value)
          if (q.isEmpty ||
              k.toLowerCase().contains(q) ||
              e.key.toLowerCase().contains(q))
            ?_region(e.key, k),
    ];
  }

  PrayerRegion? find(String provinsi, String kabkota) =>
      kabkotaOf(provinsi).contains(kabkota) ? _region(provinsi, kabkota) : null;

  PrayerRegion? _region(String provinsi, String kabkota) {
    final zone = zoneOfProvince(provinsi);
    return zone == null
        ? null
        : PrayerRegion(provinsi: provinsi, kabkota: kabkota, zone: zone);
  }
}
