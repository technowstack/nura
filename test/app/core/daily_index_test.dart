import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/daily_index.dart';

void main() {
  test('epoch is 2026-01-01', () {
    expect(dayIndex(DateTime(2026, 1, 1)), 0);
    expect(dayIndex(DateTime(2026, 1, 2)), 1);
    expect(dayIndex(DateTime(2025, 12, 31)), -1);
    expect(dayIndex(DateTime(2026, 12, 31)), 364);
  });

  test('leap day counts', () {
    expect(dayIndex(DateTime(2028, 3, 1)) - dayIndex(DateTime(2028, 2, 28)), 2);
    expect(dayIndex(DateTime(2027, 1, 1)), 365);
  });

  test('time of day and zone do not matter', () {
    expect(
      dayIndex(DateTime(2026, 5, 3, 0, 0)),
      dayIndex(DateTime(2026, 5, 3, 23, 59)),
    );
    expect(
      dayIndex(DateTime.utc(2026, 5, 3, 23)),
      dayIndex(DateTime(2026, 5, 3)),
    );
  });
}
