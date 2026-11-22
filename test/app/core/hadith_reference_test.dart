import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/hadith_reference.dart';
import 'package:nura/content_pipeline/content_schema.dart';

void main() {
  test('short book names are exactly the owner list', () {
    expect(hadithBookNamesShort, {
      'bukhari': 'Bukhari',
      'muslim': 'Muslim',
      'abu-daud': 'Abu Daud',
      'tirmidzi': 'Tirmidzi',
      'nasai': "Nasa'i",
      'ibnu-majah': 'Ibnu Majah',
      'ahmad': 'Ahmad',
      'malik': 'Malik',
      'darimi': 'Darimi',
    });
    expect(hadithBookNamesShort.keys, hadithBookNames.keys);
  });

  test('hadithReference builds HR. <short name> No. <n>', () {
    expect(hadithReference('bukhari', 1), 'HR. Bukhari No. 1');
    expect(hadithReference('nasai', 20), "HR. Nasa'i No. 20");
    expect(hadithReference('ibnu-majah', 4360), 'HR. Ibnu Majah No. 4360');
    for (final e in hadithBookNamesShort.entries) {
      expect(hadithReference(e.key, 7), 'HR. ${e.value} No. 7');
    }
  });

  test('unknown slug is kept as is and never throws', () {
    expect(hadithReference('lainnya', 3), 'HR. lainnya No. 3');
  });
}
