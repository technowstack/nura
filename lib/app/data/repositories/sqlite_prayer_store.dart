import '../models/prayer_day.dart';
import '../models/prayer_region.dart';
import '../sources/setting_keys.dart';
import '../sources/user_database.dart';
import 'prayer_store.dart';

class SqlitePrayerStore implements PrayerStore {
  SqlitePrayerStore(this._db);

  final UserDatabase _db;

  static String _notifyKey(PrayerName p) => switch (p) {
    PrayerName.subuh => SettingKeys.notifyFajr,
    PrayerName.dzuhur => SettingKeys.notifyDhuhr,
    PrayerName.ashar => SettingKeys.notifyAsr,
    PrayerName.maghrib => SettingKeys.notifyMaghrib,
    PrayerName.isya => SettingKeys.notifyIsha,
  };

  @override
  PrayerRegion? getLocation() {
    final rows = _db.raw.select(
      'SELECT provinsi, kabkota FROM prayer_location WHERE id = 1',
    );
    if (rows.isEmpty) return null;
    final provinsi = rows.single['provinsi'] as String;
    final zone = zoneOfProvince(provinsi);
    if (zone == null) return null;
    return PrayerRegion(
      provinsi: provinsi,
      kabkota: rows.single['kabkota'] as String,
      zone: zone,
    );
  }

  @override
  void setLocation(PrayerRegion r, {required String source}) => _db.raw.execute(
    'INSERT INTO prayer_location (id, provinsi, kabkota, source) '
    'VALUES (1, ?, ?, ?) ON CONFLICT(id) DO UPDATE SET '
    'provinsi = excluded.provinsi, kabkota = excluded.kabkota, '
    'source = excluded.source',
    [r.provinsi, r.kabkota, source],
  );

  @override
  PrayerDay? getDay(String date, PrayerRegion r) {
    final rows = _db.raw.select(
      'SELECT * FROM prayer_day WHERE date = ? AND provinsi = ? AND kabkota = ?',
      [date, r.provinsi, r.kabkota],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return PrayerDay(
      date: date,
      imsak: row['imsak'] as String?,
      subuh: row['subuh'] as String?,
      terbit: row['terbit'] as String?,
      dhuha: row['dhuha'] as String?,
      dzuhur: row['dzuhur'] as String?,
      ashar: row['ashar'] as String?,
      maghrib: row['maghrib'] as String?,
      isya: row['isya'] as String?,
      source: PrayerSource.values.byName(row['source'] as String),
      fetchedAt: row['fetched_at'] as int,
    );
  }

  void _putDay(PrayerRegion r, PrayerDay d) => _db.raw.execute(
    'INSERT OR REPLACE INTO prayer_day (date, provinsi, kabkota, imsak, subuh, '
    'terbit, dhuha, dzuhur, ashar, maghrib, isya, source, fetched_at) '
    'VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)',
    [
      d.date,
      r.provinsi,
      r.kabkota,
      d.imsak,
      d.subuh,
      d.terbit,
      d.dhuha,
      d.dzuhur,
      d.ashar,
      d.maghrib,
      d.isya,
      d.source.name,
      d.fetchedAt,
    ],
  );

  @override
  void saveMonth(PrayerRegion r, int year, int month, List<PrayerDay> days) {
    if (days.isEmpty) {
      throw ArgumentError.value(days, 'days', 'use markMonthNone for empty');
    }
    final raw = _db.raw;
    final fetchedAt = days.first.fetchedAt;
    raw.execute('BEGIN');
    try {
      for (final d in days) {
        _putDay(r, d);
      }
      _setMonth(r, year, month, MonthStatus.ok, fetchedAt);
      raw.execute('COMMIT');
    } catch (_) {
      raw.execute('ROLLBACK');
      rethrow;
    }
  }

  void _setMonth(PrayerRegion r, int year, int month, MonthStatus s, int at) =>
      _db.raw.execute(
        'INSERT OR REPLACE INTO prayer_month '
        '(provinsi, kabkota, year, month, status, fetched_at) '
        'VALUES (?, ?, ?, ?, ?, ?)',
        [r.provinsi, r.kabkota, year, month, s.name, at],
      );

  @override
  void markMonthNone(PrayerRegion r, int year, int month, int nowMs) =>
      _setMonth(r, year, month, MonthStatus.none, nowMs);

  @override
  MonthRecord? getMonth(PrayerRegion r, int year, int month) {
    final rows = _db.raw.select(
      'SELECT status, fetched_at FROM prayer_month WHERE provinsi = ? '
      'AND kabkota = ? AND year = ? AND month = ?',
      [r.provinsi, r.kabkota, year, month],
    );
    if (rows.isEmpty) return null;
    return MonthRecord(
      status: MonthStatus.values.byName(rows.single['status'] as String),
      fetchedAt: rows.single['fetched_at'] as int,
    );
  }

  @override
  void saveCalcDay(PrayerRegion r, PrayerDay d) {
    final existing = getDay(d.date, r);
    if (existing != null && existing.source == PrayerSource.api) return;
    _putDay(r, d);
  }

  @override
  int apiDaysFrom(String date, PrayerRegion r) =>
      _db.raw.select(
            "SELECT COUNT(*) c FROM prayer_day WHERE source = 'api' "
            'AND date >= ? AND provinsi = ? AND kabkota = ?',
            [date, r.provinsi, r.kabkota],
          ).single['c']
          as int;

  @override
  bool notifyEnabled(PrayerName p) => _db.getSetting(_notifyKey(p)) == 'true';

  @override
  void setNotifyEnabled(PrayerName p, bool v) =>
      _db.setSetting(_notifyKey(p), v.toString());
}
