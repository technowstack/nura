import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sqlite3/sqlite3.dart';

// Runs against the generated content.db (tool/prepare_content.sh). A missing
// db fails the test on purpose.
void main() {
  late Database db;

  setUpAll(() {
    final file = File('assets/db/content.db');
    if (!file.existsSync()) {
      fail('assets/db/content.db is missing: run tool/prepare_content.sh');
    }
    db = sqlite3.open(file.path, mode: OpenMode.readOnly);
  });
  tearDownAll(() => db.dispose());

  int count(String list) =>
      db.select('SELECT COUNT(*) c FROM daily_hadith WHERE list = ?', [
            list,
          ]).single['c']
          as int;

  Set<String> keys(String list) => {
    for (final r in db.select(
      'SELECT h.book_slug b, h.number n FROM daily_hadith d '
      'JOIN hadith h ON h.id = d.hadith_id WHERE d.list = ?',
      [list],
    ))
      '${r['b']}:${r['n']}',
  };

  test('candidate counts match the measured facts', () {
    expect(count('default'), 1271);
    expect(count('all'), 5102);
  });

  test('misaligned examples are in neither list', () {
    for (final n in [112, 274, 660, 915, 1175]) {
      expect(keys('default'), isNot(contains('bukhari:$n')));
      expect(keys('all'), isNot(contains('bukhari:$n')));
    }
  });

  test('approved examples are in default with the exact matan', () {
    final want = {
      34: 'Barangsiapa menegakkan lailatul qodar karena iman dan mengharap pahala, maka diampuni dosa-dosanya yang telah lalu',
      576:
          "Apabila kalian mendengar adzan, maka jawablah seperti apa yang diucapkan mu'adzin.",
      588:
          'Di dua adzan (adzan dan iqamat) ada shalat sunah -beliau ucapkan tiga kali- bagi yang mau.',
      1945:
          'Sumpah itu melariskan dagangan jual beli namun menghilangkan barakah',
      2052:
          'Siapa yang menjual pohon kurma yang telah dikawinkan maka buahnya nanti menjadi hak penjual kecuali disyaratkan oleh pembeli',
      1934:
          'Allah merahmati orang yang memudahkan ketika menjual dan ketika membeli dan juga orang yang meminta haknya',
    };
    for (final e in want.entries) {
      final rows = db.select(
        'SELECT h.translation_id t, d.tr_start s, d.tr_end e '
        'FROM daily_hadith d JOIN hadith h ON h.id = d.hadith_id '
        "WHERE d.list = 'default' AND h.book_slug = 'bukhari' AND h.number = ?",
        [e.key],
      );
      expect(rows, hasLength(1), reason: 'bukhari ${e.key}');
      final r = rows.single;
      expect(
        (r['t'] as String).substring(r['s'] as int, r['e'] as int),
        e.value,
      );
    }
  });

  test('default holds only Bukhari and Muslim', () {
    expect(keys('default').map((k) => k.split(':').first).toSet(), {
      'bukhari',
      'muslim',
    });
  });

  test('source exclusion list is valid json', () {
    final f = File('data-source/meta/daily_hadith_exclude.json');
    expect(jsonDecode(f.readAsStringSync()), isA<List<dynamic>>());
  });
}
