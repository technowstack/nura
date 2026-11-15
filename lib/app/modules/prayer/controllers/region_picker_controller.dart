import 'package:get/get.dart';

import '../../../data/models/prayer_region.dart';
import '../../../data/models/prayer_regions.dart';

/// Picker state: provinces, then the kab/kota of one province, or a name
/// search across all regions.
class RegionPickerController extends GetxController {
  RegionPickerController(this.regions);

  final PrayerRegions regions;

  String? province;
  String query = '';

  bool get searching => query.trim().isNotEmpty;

  List<String> get provinces => regions.provinces;

  List<PrayerRegion> get kabkota {
    final p = province;
    return p == null
        ? const []
        : regions.search('').where((r) => r.provinsi == p).toList();
  }

  List<PrayerRegion> get results => regions.search(query);

  void openProvince(String p) {
    province = p;
    update();
  }

  void setQuery(String q) {
    query = q;
    update();
  }

  /// Returns true when it stepped back from a province list.
  bool back() {
    if (province == null) return false;
    province = null;
    update();
    return true;
  }
}
