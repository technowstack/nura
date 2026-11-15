import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/data/models/ayah.dart';
import 'package:nura/app/data/models/daily_content.dart';
import 'package:nura/app/data/models/hadith.dart';
import 'package:nura/app/data/repositories/sqlite_daily_content_repository.dart';
import 'package:nura/app/data/sources/content_database.dart';
import 'package:nura/content_pipeline/content_schema.dart';
import 'package:sqlite3/sqlite3.dart';

// Non-BMP char (2 UTF-16 units) and combining marks before the matan.
const _pre = '\u{1F600}';
const _matan = 'بَسْمِ اللَّهِ';
const _arab = '$_pre$_matan tail';
const _trPre = 'Sanad: ';
const _trMatan = 'Sesungguhnya amal';
const _tr = '$_trPre$_trMatan.';

int _u16(String s) => s.length;

void main() {
  late Directory tmp;
  late Database db;
  late ContentDatabase content;

  void hadithRow(int id, String slug, int n, {String? arab, String? tr}) =>
      db.execute('INSERT INTO hadith VALUES (?,?,?,?,?,?)', [
        id,
        slug,
        n,
        arab ?? _arab,
        tr ?? _tr,
        0,
      ]);

  void daily(String list, int seq, int id, [List<int>? o]) {
    final off =
        o ??
        [
          _u16(_pre),
          _u16(_pre) + _u16(_matan),
          _u16(_trPre),
          _u16(_trPre) + _u16(_trMatan),
        ];
    db.execute('INSERT INTO daily_hadith VALUES (?,?,?,?,?,?,?)', [
      list,
      seq,
      id,
      ...off,
    ]);
  }

  SqliteDailyContentRepository open() {
    db.dispose();
    content = ContentDatabase.open(File('${tmp.path}/c.db'));
    addTearDown(content.close);
    return SqliteDailyContentRepository(content);
  }

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_daily_');
    addTearDown(() => tmp.deleteSync(recursive: true));
    db = sqlite3.open('${tmp.path}/c.db');
    for (final ddl in contentSchemaDdl) {
      db.execute(ddl);
    }
    db.execute(
      "INSERT INTO meta VALUES ('data_version','t'),('schema_version','1')",
    );
    db.execute(
      "INSERT INTO surah VALUES (94,'x','Asy-Syarh','x',8,'Makkiyah')",
    );
    db.execute("INSERT INTO ayah VALUES (1,94,6,'arab6','tr6','')");
    db.execute("INSERT INTO ayah VALUES (2,94,7,'arab7','tr7','')");
    db.execute(
      "INSERT INTO hadith_book VALUES ('bukhari','Shahih Bukhari',0,0)",
    );
    db.execute("INSERT INTO hadith_book VALUES ('muslim','Shahih Muslim',0,1)");
  });

  group('hadith', () {
    test('matan is the exact substring by UTF-16 offsets, with reference', () {
      hadithRow(1, 'bukhari', 34);
      daily('default', 0, 1);
      final c = open().hadithFor(DateTime(2026, 1, 1), HadithSource.defaultBm)!;
      expect(c.kind, DailyKind.hadith);
      expect(c.arab, _matan);
      expect(c.translation, _trMatan);
      expect(c.reference, 'HR. Shahih Bukhari No. 34');
      expect(c.deepLink, 'nura://hadith/bukhari/34');
      expect(c.hadithRef, const HadithRef('bukhari', 34));
    });

    test('wraps for index beyond count and negative index', () {
      for (var i = 0; i < 3; i++) {
        hadithRow(i + 1, 'bukhari', 10 + i);
        daily('default', i, i + 1);
      }
      final r = open();
      int num(DateTime d) =>
          r.hadithFor(d, HadithSource.defaultBm)!.hadithRef!.number;
      expect(num(DateTime(2026, 1, 1)), 10);
      expect(num(DateTime(2026, 1, 2)), 11);
      expect(num(DateTime(2026, 1, 4)), 10); // index 3 wraps
      expect(num(DateTime(2025, 12, 31)), 12); // index -1 wraps
      expect(num(DateTime(2026, 1, 1, 23, 59)), 10);
    });

    test('allBooks list is independent of defaultBm', () {
      hadithRow(1, 'bukhari', 1);
      hadithRow(2, 'muslim', 2);
      daily('default', 0, 1);
      daily('all', 0, 2);
      final r = open();
      final d = DateTime(2026, 1, 1);
      expect(
        r.hadithFor(d, HadithSource.defaultBm)!.hadithRef!.slug,
        'bukhari',
      );
      expect(r.hadithFor(d, HadithSource.allBooks)!.hadithRef!.slug, 'muslim');
    });

    test('corrupt offsets give null', () {
      hadithRow(1, 'bukhari', 1);
      for (final (i, o) in [
        [0, 999, 0, 1],
        [5, 2, 0, 1],
        [-1, 2, 0, 1],
        [0, 1, 0, 999],
      ].indexed) {
        daily('default', i, 1, o);
      }
      final r = open();
      for (var i = 0; i < 4; i++) {
        expect(
          r.hadithFor(DateTime(2026, 1, 1 + i), HadithSource.defaultBm),
          isNull,
        );
      }
    });

    test('empty list gives null', () {
      expect(
        open().hadithFor(DateTime(2026, 1, 1), HadithSource.allBooks),
        isNull,
      );
    });
  });

  group('ayah', () {
    test('empty daily_ayah', () {
      final r = open();
      expect(r.hasAyah, isFalse);
      expect(r.ayahFor(DateTime(2026, 1, 1)), isNull);
    });

    test('reference, deep link and wrap', () {
      db.execute('INSERT INTO daily_ayah VALUES (0,1),(1,2)');
      final r = open();
      expect(r.hasAyah, isTrue);
      final c = r.ayahFor(DateTime(2026, 1, 1))!;
      expect(c.kind, DailyKind.ayah);
      expect(c.arab, 'arab6');
      expect(c.translation, 'tr6');
      expect(c.reference, 'QS. Asy-Syarh: 6');
      expect(c.deepLink, 'nura://ayah/94/6');
      expect(c.ayahRef, const AyahRef(94, 6));
      expect(r.ayahFor(DateTime(2026, 1, 2))!.reference, 'QS. Asy-Syarh: 7');
      expect(r.ayahFor(DateTime(2026, 1, 3))!.reference, 'QS. Asy-Syarh: 6');
      expect(r.ayahFor(DateTime(2025, 12, 31))!.reference, 'QS. Asy-Syarh: 7');
    });
  });
}
