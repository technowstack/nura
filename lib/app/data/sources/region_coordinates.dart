import '../models/prayer_region.dart';

/// Source of region coordinates for the offline calculator.
abstract interface class RegionCoordinates {
  ({double lat, double lng})? of(PrayerRegion r);
}

/// v1: no coordinates are available.
class NoRegionCoordinates implements RegionCoordinates {
  const NoRegionCoordinates();

  @override
  ({double lat, double lng})? of(PrayerRegion r) => null;
}
