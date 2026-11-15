enum PrayerZone {
  wib(7, 'WIB'),
  wita(8, 'WITA'),
  wit(9, 'WIT');

  const PrayerZone(this.offsetHours, this.label);

  final int offsetHours;
  final String label;
}

const _zoneProvinces = <PrayerZone, List<String>>{
  PrayerZone.wib: [
    'Aceh',
    'Sumatera Utara',
    'Sumatera Barat',
    'Riau',
    'Kepulauan Riau',
    'Jambi',
    'Sumatera Selatan',
    'Kepulauan Bangka Belitung',
    'Bengkulu',
    'Lampung',
    'Banten',
    'DKI Jakarta',
    'Jawa Barat',
    'Jawa Tengah',
    'D.I. Yogyakarta',
    'Jawa Timur',
    'Kalimantan Barat',
    'Kalimantan Tengah',
  ],
  PrayerZone.wita: [
    'Bali',
    'Nusa Tenggara Barat',
    'Nusa Tenggara Timur',
    'Kalimantan Selatan',
    'Kalimantan Timur',
    'Kalimantan Utara',
    'Sulawesi Utara',
    'Gorontalo',
    'Sulawesi Tengah',
    'Sulawesi Selatan',
    'Sulawesi Tenggara',
    'Sulawesi Barat',
  ],
  PrayerZone.wit: ['Maluku', 'Maluku Utara', 'Papua', 'Papua Barat'],
};

final _zoneByProvince = <String, PrayerZone>{
  for (final e in _zoneProvinces.entries)
    for (final p in e.value) p: e.key,
};

/// Returns null for a province not in the table.
PrayerZone? zoneOfProvince(String provinsi) => _zoneByProvince[provinsi];

class PrayerRegion {
  const PrayerRegion({
    required this.provinsi,
    required this.kabkota,
    required this.zone,
  });

  final String provinsi;
  final String kabkota;
  final PrayerZone zone;

  String get key => '$provinsi|$kabkota';
}
