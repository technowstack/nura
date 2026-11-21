import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:nura/content_pipeline/content_db_verifier.dart';
import 'package:nura/content_pipeline/content_schema.dart';
import 'package:nura/content_pipeline/matan_extractor.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixtures.dart';
import '../support/source_tree.dart';

void main() {
  late Directory tempDir;
  late File built;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nura_verify_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    built = File('${tempDir.path}/content.db');
    buildContentDb(sourceRoot: fixtureDir(''), output: built);
  });

  VerificationReport verifyTampered(String sql, {Directory? source}) {
    final copy = built.copySync('${tempDir.path}/tampered.db');
    final db = sqlite3.open(copy.path)..execute(sql);
    db.dispose();
    return verifyContentDb(
      sourceRoot: source ?? fixtureDir(''),
      database: copy,
    );
  }

  Directory sourceCopy() {
    final dst = Directory('${tempDir.path}/src')..createSync();
    for (final f in fixtureDir(
      '',
    ).listSync(recursive: true).whereType<File>()) {
      final rel = f.path
          .substring(fixtureDir('').path.length)
          .replaceFirst(RegExp('^/'), '');
      File('${dst.path}/$rel')
        ..createSync(recursive: true)
        ..writeAsBytesSync(f.readAsBytesSync());
    }
    return dst;
  }

  test('freshly built fixture db verifies ok', () {
    final r = verifyContentDb(sourceRoot: fixtureDir(''), database: built);
    expect(r.errors, isEmpty);
    expect(r.ok, isTrue);
  });

  test('one changed character in ayah.arab is an error', () {
    final r = verifyTampered("UPDATE ayah SET arab = arab || 'x' WHERE id = 1");
    expect(r.ok, isFalse);
    expect(r.errors.single, contains('ayah 1:1'));
  });

  test('trimmed trailing space in hadith is an error', () {
    final r = verifyTampered(
      'UPDATE hadith SET arab = rtrim(arab) WHERE number = 99999',
    );
    expect(r.ok, isFalse);
    expect(r.errors.single, contains('hadith malik:99999 arab differs'));
  });

  test('missing row is an error', () {
    final r = verifyTampered('DELETE FROM hadith WHERE id = 1');
    expect(r.ok, isFalse);
    expect(r.errors, contains(startsWith('missing hadith ')));
  });

  test('source checksum mismatch is an error', () {
    final src = sourceCopy();
    final f = File('${src.path}/meta/surah_info.json');
    f.writeAsStringSync('${f.readAsStringSync()} ');
    final r = verifyContentDb(sourceRoot: src, database: built);
    expect(r.ok, isFalse);
    expect(r.errors, contains(contains('hash mismatch: meta/surah_info.json')));
  });

  test('meta.source_checksums mismatch is an error', () {
    final r = verifyTampered(
      "UPDATE meta SET value = '{}' WHERE key = 'source_checksums'",
    );
    expect(r.ok, isFalse);
    expect(r.errors.single, contains('source_checksums'));
  });

  test('empty revelation is a warning, not an error', () {
    final r = verifyContentDb(sourceRoot: fixtureDir(''), database: built);
    expect(r.ok, isTrue);
    expect(r.warnings, contains(contains('112')));
  });

  test('unknown revelation is an error', () {
    final r = verifyTampered(
      "UPDATE surah SET revelation = 'mekah' WHERE number = 1",
    );
    expect(r.errors, contains(contains('unknown revelation')));
  });

  test('empty revelation is an error in full mode', () {
    final r = verifyContentDb(
      sourceRoot: fixtureDir(''),
      database: built,
      expected: fullDatasetTotals,
    );
    expect(r.errors, contains(contains('surah 112: empty revelation')));
  });

  group('juz', () {
    VerificationReport withJuz(List<String> rows) {
      final src = sourceCopy();
      File('${src.path}/meta/juz.json').writeAsStringSync('[]');
      return verifyTampered(
        'INSERT INTO juz VALUES ${rows.join(',')}',
        source: src,
      );
    }

    test('gap, wrong reference start and uneven coverage are errors', () {
      final gap = withJuz(['(1, 1, 1, 1, 7)']);
      expect(gap.errors, contains(contains('juz cover 7 of 22 ayat')));
      final overlap = withJuz(['(1, 1, 1, 100, 11)', '(2, 1, 1, 112, 4)']);
      expect(overlap.errors, contains(contains('juz 2 starts 1:1')));
      expect(overlap.errors, contains(contains('gap or overlap')));
    });

    test('an end beyond the surah length or surah 115 is an error', () {
      final tooLong = withJuz(['(1, 1, 1, 112, 5)']);
      expect(tooLong.errors, contains(contains('not a real ayah')));
      final beyond = withJuz(['(1, 1, 1, 115, 1)']);
      expect(beyond.errors, contains(contains('not a real ayah')));
    });
  });

  test('expected totals mismatch is an error', () {
    final r = verifyContentDb(
      sourceRoot: fixtureDir(''),
      database: built,
      expected: fullDatasetTotals,
    );
    expect(r.ok, isFalse);
  });

  test('stale ayah_count is an error', () {
    final r = verifyTampered(
      'UPDATE surah SET ayah_count = 99 WHERE number = 1',
    );
    expect(r.ok, isFalse);
  });

  test('missing fts row is an error', () {
    final r = verifyTampered('DELETE FROM ayah_fts_docsize WHERE id = 1');
    expect(r.ok, isFalse);
    expect(r.errors, contains(startsWith('ayah_fts count')));
  });

  String q(String v) => v.replaceAll("'", "''");

  for (final t in ['ayah', 'hadith']) {
    test('wrong word in ${t}_fts is caught by the MATCH probe', () {
      final db = sqlite3.open(built.path);
      final rows = db.select('SELECT id, arab, translation_id FROM $t');
      db.dispose();
      final fts = '${t}_fts';
      // Corrupt every index row, so whichever row is probed is wrong.
      final sql = StringBuffer();
      for (final row in rows) {
        final id = row['id'];
        final arab = normalizeArabicForSearch(row['arab'] as String);
        final tr = normalizeIndonesianForSearch(
          row['translation_id'] as String,
        );
        sql
          ..write(
            "INSERT INTO $fts($fts, rowid, arab, translation) "
            "VALUES ('delete', $id, '${q(arab)}', '${q(tr)}'); ",
          )
          ..write(
            "INSERT INTO $fts(rowid, arab, translation) "
            "VALUES ($id, 'zzz', 'zzz'); ",
          );
      }
      final r = verifyTampered(sql.toString());
      expect(r.ok, isFalse);
      expect(r.errors, contains(startsWith('$fts MATCH arab:"')));
      expect(r.errors.join(), contains('does not find rowid'));
    });
  }

  group('content.version', () {
    test('matching sidecar passes', () {
      final r = buildContentDb(
        sourceRoot: fixtureDir(''),
        output: File('${tempDir.path}/x.db'),
      );
      final v = File('${tempDir.path}/content.version')
        ..writeAsStringSync(r.contentVersion);
      final rep = verifyContentDb(
        sourceRoot: fixtureDir(''),
        database: File('${tempDir.path}/x.db'),
        versionFile: v,
      );
      expect(rep.errors, isEmpty);
    });

    test('wrong or missing sidecar fails', () {
      final v = File('${tempDir.path}/content.version')
        ..writeAsStringSync('1:0000000000000000');
      final bad = verifyContentDb(
        sourceRoot: fixtureDir(''),
        database: built,
        versionFile: v,
      );
      expect(bad.errors.join(), contains('content.version'));
      v.deleteSync();
      final missing = verifyContentDb(
        sourceRoot: fixtureDir(''),
        database: built,
        versionFile: v,
      );
      expect(missing.errors.join(), contains('content.version'));
    });
  });

  group('daily_ayah', () {
    late Directory src;
    late File db;

    setUp(() {
      src = makeSource(
        tempDir,
        'ayah-src',
        files: {
          'meta/daily_ayah.json': '[{"surah":1,"ayah":2},{"surah":1,"ayah":3}]',
        },
      );
      db = File('${tempDir.path}/ayah.db');
      buildContentDb(sourceRoot: src, output: db);
    });

    VerificationReport verifyAyah(String sql) {
      final copy = db.copySync('${tempDir.path}/ayah-tampered.db');
      final d = sqlite3.open(copy.path)..execute(sql);
      d.dispose();
      return verifyContentDb(sourceRoot: src, database: copy);
    }

    test('a populated daily_ayah verifies ok', () {
      expect(verifyContentDb(sourceRoot: src, database: db).errors, isEmpty);
    });

    test('a missing ayah, a seq gap and a duplicate are errors', () {
      expect(
        verifyAyah(
          'UPDATE daily_ayah SET ayah_id = 999999 WHERE seq = 0',
        ).errors,
        anyElement(contains('missing')),
      );
      expect(
        verifyAyah('UPDATE daily_ayah SET seq = 5 WHERE seq = 1').errors,
        anyElement(contains('not dense')),
      );
      expect(
        verifyAyah(
          'UPDATE daily_ayah SET ayah_id = (SELECT ayah_id FROM daily_ayah WHERE seq = 0) WHERE seq = 1',
        ).errors,
        anyElement(contains('twice')),
      );
    });
  });

  group('daily_hadith', () {
    late Directory src;
    late File db;

    Map<String, String?> files({Map<String, String?> extra = const {}}) => {
      'hadith/bukhari.json': hadithJson([
        goodHadith(1),
        narrativeHadith(2),
        goodHadith(3),
      ]),
      'hadith/muslim.json': hadithJson([goodHadith(1)]),
      ...extra,
    };

    setUp(() {
      src = makeSource(tempDir, 'daily-src', files: files());
      db = File('${tempDir.path}/daily.db');
      buildContentDb(sourceRoot: src, output: db);
    });

    VerificationReport verifyDaily(String sql, {Directory? source}) {
      final copy = db.copySync('${tempDir.path}/daily-tampered.db');
      final d = sqlite3.open(copy.path)..execute(sql);
      d.dispose();
      return verifyContentDb(sourceRoot: source ?? src, database: copy);
    }

    test('an honest build verifies ok', () {
      final r = verifyContentDb(sourceRoot: src, database: db);
      expect(r.errors, isEmpty);
    });

    test('offset outside the text or start >= end is an error', () {
      var r = verifyDaily(
        'UPDATE daily_hadith SET arab_end = 100000 WHERE list = \'all\' AND seq = 0',
      );
      expect(r.errors.join('\n'), contains('offsets outside'));
      r = verifyDaily(
        'UPDATE daily_hadith SET tr_start = tr_end WHERE list = \'all\' AND seq = 0',
      );
      expect(r.errors.join('\n'), contains('offsets outside'));
      r = verifyDaily(
        'UPDATE daily_hadith SET arab_start = -1 WHERE list = \'all\' AND seq = 0',
      );
      expect(r.errors.join('\n'), contains('offsets outside'));
    });

    test('seq with a gap is an error', () {
      final r = verifyDaily(
        "UPDATE daily_hadith SET seq = 9 WHERE list = 'default' AND seq = 0",
      );
      expect(r.errors.join('\n'), contains('seq not dense'));
    });

    test('a slice differing from the re-run rule is an error', () {
      final r = verifyDaily(
        'UPDATE daily_hadith SET arab_start = arab_start + 1 WHERE list = \'all\' AND seq = 0',
      );
      expect(r.errors.join('\n'), contains('slices differ from extractMatan'));
    });

    test('a hadith that does not qualify is an error', () {
      final d = sqlite3.open(db.path, mode: OpenMode.readOnly);
      final id = d
          .select(
            "SELECT id FROM hadith WHERE book_slug='bukhari' AND number=2",
          )
          .single['id'];
      d.dispose();
      final r = verifyDaily(
        'INSERT INTO daily_hadith VALUES (\'all\', 9999, $id, 0, 12, 0, 12)'
        '; UPDATE daily_hadith SET seq = seq',
      );
      expect(r.errors.join('\n'), contains('bukhari:2'));
    });

    test('a hadith twice in one list is an error', () {
      final r = verifyDaily(
        "INSERT INTO daily_hadith SELECT list, 99, hadith_id, arab_start, "
        "arab_end, tr_start, tr_end FROM daily_hadith "
        "WHERE list = 'all' AND seq = 0",
      );
      expect(r.errors.join('\n'), contains('appears twice in the all list'));
    });

    test('a short or empty list is an error (completeness)', () {
      var r = verifyDaily(
        "DELETE FROM daily_hadith WHERE list = 'default' "
        "AND seq = (SELECT MAX(seq) FROM daily_hadith WHERE list = 'default')",
      );
      expect(
        r.errors.join('\n'),
        contains('default list has 2 rows, 3 qualify'),
      );
      r = verifyDaily("DELETE FROM daily_hadith WHERE list = 'default'");
      expect(r.errors.join('\n'), contains('default list has 0 rows'));
    });

    test('an excluded hadith in a list is an error', () {
      final excluded = makeSource(
        tempDir,
        'excl',
        files: files(
          extra: {
            'meta/daily_hadith_exclude.json': '[{"book":"bukhari","number":1}]',
          },
        ),
      );
      final r = verifyContentDb(sourceRoot: excluded, database: db);
      expect(r.errors.join('\n'), contains('excluded hadith bukhari:1'));
    });

    test('a truncated hadith in a list is an error', () {
      final cut = (
        number: 50,
        arab: arabWithMatan(
          'مَنْ يَقُمْ لَيْلَةَ الْقَدْرِ إِيمَانًا',
          sanad: 'ب ' * 8200,
        ),
        id: translationWithMatan(
          'Barangsiapa menegakkan malam qadar dengan iman',
        ),
      );
      expect(
        utf8.encode(cut.arab).length,
        greaterThanOrEqualTo(kSourceTruncationBytes),
      );
      final withCut = makeSource(
        tempDir,
        'cut',
        files: files(
          extra: {
            'hadith/bukhari.json': hadithJson([goodHadith(1), cut]),
          },
        ),
      );
      final out = File('${tempDir.path}/cut.db');
      buildContentDb(sourceRoot: withCut, output: out);
      final m = extractMatan(cut.arab, cut.id);
      expect(m, isNotNull);
      final d = sqlite3.open(out.path);
      final id = d.select("SELECT id FROM hadith WHERE number=50").single['id'];
      final n = d
          .select("SELECT COUNT(*) c FROM daily_hadith WHERE list='default'")
          .single['c'];
      d.execute(
        "INSERT INTO daily_hadith VALUES ('default', $n, $id, ${m!.arabStart}, ${m.arabEnd}, ${m.trStart}, ${m.trEnd})",
      );
      d.dispose();
      final r = verifyContentDb(sourceRoot: withCut, database: out);
      expect(r.errors.join('\n'), contains('truncated hadith bukhari:50'));
    });

    test('a default list holding another book is an error', () {
      final d = sqlite3.open(db.path, mode: OpenMode.readOnly);
      final id = d
          .select("SELECT id FROM hadith WHERE book_slug='malik' AND number=4")
          .single['id'];
      final m = extractMatan(
        d.select('SELECT arab FROM hadith WHERE id = ?', [id]).single['arab']
            as String,
        d.select('SELECT translation_id FROM hadith WHERE id = ?', [
              id,
            ]).single['translation_id']
            as String,
      );
      d.dispose();
      final r = verifyDaily(
        "INSERT INTO daily_hadith VALUES ('default', 99, $id, ${m!.arabStart}, ${m.arabEnd}, ${m.trStart}, ${m.trEnd})",
      );
      expect(r.errors.join('\n'), contains('default list'));
    });

    test('offsets stay correct with non-BMP and combining characters', () {
      final emoji = (
        number: 60,
        arab:
            'x\u{1F600} ${arabWithMatan('مَنْ يَقُمْ لَيْلَةَ الْقَدْرِ إِيمَانًا')}',
        id: 'Dari [A] \u{1F600} shallallahu \'alaihi wasallam bersabda: "Barangsiapa e\u0301 menegakkan malam \u{1F600} qadar"',
      );
      final s = makeSource(
        tempDir,
        'emoji',
        files: files(
          extra: {
            'hadith/bukhari.json': hadithJson([goodHadith(1), emoji]),
          },
        ),
      );
      final out = File('${tempDir.path}/emoji.db');
      buildContentDb(sourceRoot: s, output: out);
      expect(verifyContentDb(sourceRoot: s, database: out).errors, isEmpty);
      final d = sqlite3.open(out.path, mode: OpenMode.readOnly);
      final r = d
          .select(
            'SELECT d.*, h.translation_id t FROM daily_hadith d JOIN hadith h ON h.id = d.hadith_id WHERE h.number = 60 AND d.list = \'default\'',
          )
          .single;
      d.dispose();
      expect(
        (r['t'] as String).substring(r['tr_start'] as int, r['tr_end'] as int),
        'Barangsiapa e\u0301 menegakkan malam \u{1F600} qadar',
      );
    });
  });
}
