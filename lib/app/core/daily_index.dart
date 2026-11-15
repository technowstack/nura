/// Days since 2026-01-01, from the y/m/d components only so DST, zone and
/// time of day never matter. Negative before the epoch.
int dayIndex(DateTime localDate) => DateTime.utc(
  localDate.year,
  localDate.month,
  localDate.day,
).difference(DateTime.utc(2026)).inDays;
