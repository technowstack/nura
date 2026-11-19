import 'package:hijri/hijri_calendar.dart';

import '../data/sources/setting_keys.dart';
import '../data/sources/user_database.dart';

/// Offline Hijri date (Umm al-Qura tables) with a user day adjustment.
///
/// The Hijri day changes at local midnight, not at Maghrib.
class HijriDateService {
  HijriDateService({required UserDatabase user}) : _db = user;

  final UserDatabase _db;

  static const _months = [
    'Muharram',
    'Safar',
    'Rabiulawal',
    'Rabiulakhir',
    'Jumadilawal',
    'Jumadilakhir',
    'Rajab',
    'Syakban',
    'Ramadhan',
    'Syawal',
    'Zulkaidah',
    'Zulhijah',
  ];

  /// Day offset in -1..1; invalid stored values read as 0.
  int get adjustDays {
    final v = int.tryParse(_db.getSetting(SettingKeys.hijriAdjust) ?? '');
    return v == null || v < -1 || v > 1 ? 0 : v;
  }

  set adjustDays(int v) =>
      _db.setSetting(SettingKeys.hijriAdjust, v.clamp(-1, 1).toString());

  /// "D NamaBulan YYYY H" for the local calendar date (time is ignored).
  String format(DateTime gregorianLocal) {
    final g = DateTime(
      gregorianLocal.year,
      gregorianLocal.month,
      gregorianLocal.day + adjustDays,
    );
    final h = HijriCalendar.fromDate(g);
    return '${h.hDay} ${_months[h.hMonth - 1]} ${h.hYear} H';
  }
}
