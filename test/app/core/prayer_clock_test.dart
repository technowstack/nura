import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/prayer_region.dart';

import '../../support/fake_prayer.dart';

void main() {
  test('todayIn uses the region zone', () {
    final c = FakeClock(DateTime.utc(2026, 11, 15, 16, 30));
    expect(c.todayIn(PrayerZone.wib), '2026-11-15');
    expect(c.todayIn(PrayerZone.wita), '2026-11-16');
    expect(c.todayIn(PrayerZone.wit), '2026-11-16');
  });

  test('instantOf converts local time to UTC', () {
    final c = FakeClock(DateTime.utc(2026));
    expect(
      c.instantOf('2026-11-01', '04:09', PrayerZone.wib),
      DateTime.utc(2026, 10, 31, 21, 9),
    );
    expect(
      c.instantOf('2026-11-01', '04:09', PrayerZone.wita),
      DateTime.utc(2026, 10, 31, 20, 9),
    );
    expect(
      c.instantOf('2026-11-01', '04:09', PrayerZone.wit),
      DateTime.utc(2026, 10, 31, 19, 9),
    );
  });
}
