import 'package:flutter/widgets.dart';
import '../../core/nura_icons.dart';
import '../../data/models/prayer_day.dart';
import 'widgets/home_hero_data.dart';

const _noTime = '--:--';
const _noRegionText = 'Pilih wilayah untuk melihat jadwal sholat';

String _two(int n) => n.toString().padLeft(2, '0');

/// The next prayer is the first time strictly after [now]; a time counts as
/// passed from its own minute (same rule as the Sholat screen).
///
/// [now] is the region's wall clock: only its fields are read, so pass the
/// region-local time (or the device time when no region is chosen). Times
/// that are missing show `--:--` and are never guessed; a [today] whose date
/// is not [now]'s date is stale and ignored.
HomeHeroData buildHeroData({
  required PrayerDay? today,
  required PrayerDay? tomorrow,
  required DateTime now,
  required String? regionLabel,
  required String hijri,
}) {
  final hasRegion = regionLabel != null && regionLabel.isNotEmpty;
  final clock = '${_two(now.hour)}:${_two(now.minute)}';
  final slots = <(String, IconData, String?)>[
    if (today != null && _isDate(today.date, now)) ...[
      ('Subuh', NuraIcons.bedtime, today.subuh),
      ('Terbit', NuraIcons.twilight, today.terbit),
      ('Dzuhur', NuraIcons.sunny, today.dzuhur),
      ('Ashar', NuraIcons.sunny, today.ashar),
      ('Maghrib', NuraIcons.twilight, today.maghrib),
      ('Isya', NuraIcons.bedtime, today.isya),
    ],
  ];
  final base = HomeHeroData(
    locationLabel: hasRegion ? regionLabel : 'Pilih wilayah',
    hijriDate: hijri,
    clock: clock,
    emptyText: hasRegion ? 'Jadwal belum tersedia' : _noRegionText,
  );
  if (slots.every((s) => s.$3 == null)) return base;

  final wall = DateTime.utc(
    now.year,
    now.month,
    now.day,
    now.hour,
    now.minute,
    now.second,
  );
  int? next;
  DateTime? nextAt;
  for (final (i, s) in slots.indexed) {
    final t = s.$3;
    // Terbit (index 1) is not a prayer: never the next one.
    if (t == null || i == 1) continue;
    final at = _at(now, t);
    if (at != null && at.isAfter(wall)) {
      next = i;
      nextAt = at;
      break;
    }
  }
  if (next == null) {
    // After the last time: Subuh of the day after, only when it is known.
    final sub = tomorrow?.subuh;
    final nextDay = DateTime.utc(now.year, now.month, now.day + 1);
    if (tomorrow != null && sub != null && _isDate(tomorrow.date, nextDay)) {
      final at = _at(nextDay, sub);
      if (at != null) {
        next = 0;
        nextAt = at;
      }
    }
  }
  final countdown = next == null || nextAt == null
      ? null
      : '${slots[next].$1} dalam ${_duration(nextAt.difference(wall))}';
  return HomeHeroData(
    locationLabel: base.locationLabel,
    hijriDate: hijri,
    clock: clock,
    emptyText: base.emptyText,
    times: [
      for (final s in slots)
        HeroPrayerTime(name: s.$1, time: s.$3 ?? _noTime, icon: s.$2),
    ],
    nextIndex: next,
    countdownText: countdown,
    approximate: today?.source != PrayerSource.api,
  );
}

bool _isDate(String date, DateTime d) =>
    date ==
    '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

/// Wall-clock instant of `HH:mm` on [day]'s date; null when malformed.
DateTime? _at(DateTime day, String hhmm) {
  final p = hhmm.split(':');
  final h = p.length == 2 ? int.tryParse(p[0]) : null;
  final m = p.length == 2 ? int.tryParse(p[1]) : null;
  if (h == null || m == null) return null;
  return DateTime.utc(day.year, day.month, day.day, h, m);
}

String _duration(Duration d) {
  final total = d.inMinutes;
  if (total < 1) return 'kurang dari 1 menit';
  final h = total ~/ 60;
  final m = total % 60;
  return [if (h > 0) '$h jam', if (m > 0) '$m menit'].join(' ');
}
