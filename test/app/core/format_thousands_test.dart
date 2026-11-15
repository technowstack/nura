import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/format_thousands.dart';

void main() {
  test('formats with dot separators', () {
    expect(formatThousands(0), '0');
    expect(formatThousands(999), '999');
    expect(formatThousands(1000), '1.000');
    expect(formatThousands(6638), '6.638');
    expect(formatThousands(38102), '38.102');
    expect(formatThousands(999999), '999.999');
    expect(formatThousands(1000000), '1.000.000');
    expect(formatThousands(-1000), '-1.000');
    expect(formatThousands(1234567), '1.234.567');
  });
}
