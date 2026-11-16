import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:nura/content_pipeline/content_schema.dart';
import 'package:nura/content_pipeline/seeded_shuffle.dart';
import 'package:nura/content_pipeline/source_models.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixture_db.dart';
import '../support/fixtures.dart';
import '../support/source_tree.dart';

void copyDir(Directory from, Directory to) {
  for (final f in from.listSync(recursive: true).whereType<File>()) {
    final rel = f.path
        .substring(from.path.length)
        .replaceFirst(RegExp('^/'), '');
    File('${to.path}/$rel')
      ..createSync(recursive: true)
      ..writeAsBytesSync(f.readAsBytesSync());
  }
}

void main() {
  late Directory tempDir;
  late Database db;
  late BuildResult result;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nura_build_');
    addTearDown(() => tempDir.deleteSync(recursive: true));
    final out = File('${tempDir.path}/content.db');
    result = buildContentDb(
      sourceRoot: fixtureDir(''),
      output: out,
      builtAt: DateTime.utc(2026, 11, 9),
    );
    db = sqlite3.open(out.path, mode: OpenMode.readOnly);
    addTearDown(db.dispose);
  });

  int count(String t) =>
      db.select('SELECT COUNT(*) c FROM $t').single['c'] as int;

  test('row counts match fixture', () {
    expect(count('surah'), 3);
    expect(count('hadith_book'), 2);
    expect(count('hadith'), 9);
    expect(result.surahCount, 3);
    expect(result.ayahCount, count('ayah'));
    expect(result.hadithCount, 9);
    expect(
      db.select('SELECT SUM(ayah_count) s FROM surah').single['s'],
      count('ayah'),
    );
  });

  test('ayah ids are global and ordered by surah then ayah', () {
    final rows = db.select(
      'SELECT id, surah_number, ayah_number FROM ayah ORDER BY id',
    );
    expect(rows.first['id'], 1);
    for (var i = 1; i < rows.length; i++) {
      expect(rows[i]['id'], i + 1);
      final a = rows[i - 1], b = rows[i];
      final up =
          (b['surah_number'] as int) > (a['surah_number'] as int) ||
          (b['surah_number'] == a['surah_number'] &&
              (b['ayah_number'] as int) > (a['ayah_number'] as int));
      expect(up, isTrue);
    }
  });

  test('raw text stored byte-identical, including trailing spaces and ZWNJ', () {
    final r = db
        .select(
          "SELECT arab, translation_id FROM hadith WHERE book_slug='malik' AND number=99999",
        )
        .single;
    expect(r['arab'], 'نص تجريبي  ');
    expect(r['translation_id'], 'teks‌ uji  dengan  spasi  ');
  });

  test('FTS finds rows by normalized words, rowid equals table id', () {
    // Normalization is applied to the index only: lowercase + no punctuation.
    final ayah = db.select(
      "SELECT id FROM ayah WHERE translation_id LIKE '%Pengasih%' LIMIT 1",
    );
    expect(ayah, isNotEmpty);
    final hits = db.select(
      "SELECT rowid FROM ayah_fts WHERE ayah_fts MATCH 'translation:pengasih'",
    );
    expect(hits.map((r) => r['rowid']), contains(ayah.first['id']));
    // Arabic without diacritics finds the diacritized source row.
    for (final r in db.select('SELECT id, arab FROM hadith')) {
      final word = normalizeArabicForSearch(
        r['arab'] as String,
      ).split(' ').firstWhere((w) => w.isNotEmpty, orElse: () => '');
      if (word.isEmpty) continue;
      final found = db.select(
        'SELECT rowid FROM hadith_fts WHERE hadith_fts MATCH ?',
        ['arab:"$word"'],
      );
      expect(found.map((x) => x['rowid']), contains(r['id']));
    }
    expect(count('ayah_fts_docsize'), count('ayah'));
    expect(count('hadith_fts_docsize'), count('hadith'));
  });

  test('ayah_fts finds a small-alef word by both spellings (Q13)', () {
    // Fixture 1:3 has ٱلرَّحْمَٰنِ: plain form الرحمن, small alef as alif الرحمان.
    final id = db
        .select(
          'SELECT id FROM ayah WHERE surah_number = 1 AND ayah_number = 3',
        )
        .first['id'];
    for (final word in ['الرحمن', 'الرحمان']) {
      final hits = db.select(
        'SELECT rowid FROM ayah_fts WHERE ayah_fts MATCH ?',
        ['arab:"$word"'],
      );
      expect(hits.map((r) => r['rowid']), contains(id), reason: word);
    }
    // Hadith text is indexed with the plain form only.
    expect(
      db.select('SELECT rowid FROM hadith_fts WHERE hadith_fts MATCH ?', [
        'arab:"الرحمان"',
      ]),
      isEmpty,
    );
  });

  test('FTS finds a diacritized source word by its literal bare form', () {
    // Fixture 1:2 starts with اَلْحَمْدُ; the query is typed without harakat.
    final hits = db.select(
      "SELECT rowid FROM ayah_fts WHERE ayah_fts MATCH 'arab:الحمد'",
    );
    expect(hits.map((r) => r['rowid']), contains(2));
  });

  test('page_size pragma is applied', () {
    expect(db.select('PRAGMA page_size').single.values.first, 16384);
  });

  test('meta has schema_version, data_version, built_at, source_checksums', () {
    final m = {
      for (final r in db.select('SELECT key, value FROM meta'))
        r['key']: r['value'],
    };
    expect(m['schema_version'], '2');
    expect(m['data_version'], matches(RegExp(r'^[0-9a-f]{16}$')));
    expect(m['built_at'], '2026-11-09T00:00:00.000Z');
    expect(m['source_checksums'], contains('quran/1.json'));
  });

  test('missing surah_info entry yields empty revelation and a warning', () {
    expect(
      db
          .select('SELECT revelation FROM surah WHERE number=112')
          .single['revelation'],
      '',
    );
    expect(
      db
          .select('SELECT revelation FROM surah WHERE number=1')
          .single['revelation'],
      'makkiyah',
    );
    expect(result.warnings, contains(contains('112')));
  });

  test('daily_ayah is empty when meta/daily_ayah.json is absent', () {
    expect(count('daily_ayah'), 0);
  });

  test('daily_ayah and juz load from optional meta files; bad pair throws', () {
    final src = Directory('${tempDir.path}/src')..createSync();
    copyDir(fixtureDir(''), src);
    File(
      '${src.path}/meta/daily_ayah.json',
    ).writeAsStringSync('[{"surah":1,"ayah":2}]');
    File('${src.path}/meta/juz.json').writeAsStringSync(
      '[{"number":1,"start_surah":1,"start_ayah":1,"end_surah":2,"end_ayah":141}]',
    );
    final out = File('${tempDir.path}/o2.db');
    buildContentDb(sourceRoot: src, output: out);
    final d = sqlite3.open(out.path, mode: OpenMode.readOnly);
    addTearDown(d.dispose);
    expect(d.select('SELECT ayah_id FROM daily_ayah').single['ayah_id'], 2);
    expect(d.select('SELECT end_ayah FROM juz').single['end_ayah'], 141);
    File(
      '${src.path}/meta/daily_ayah.json',
    ).writeAsStringSync('[{"surah":1,"ayah":99}]');
    expect(
      () => buildContentDb(
        sourceRoot: src,
        output: File('${tempDir.path}/o3.db'),
      ),
      throwsA(anything),
    );
    expect(File('${tempDir.path}/o3.db').existsSync(), isFalse);
  });

  test('missing CHECKSUMS.sha256 throws', () {
    final src = Directory('${tempDir.path}/nosum')..createSync();
    copyDir(fixtureDir(''), src);
    File('${src.path}/CHECKSUMS.sha256').deleteSync();
    expect(
      () => buildContentDb(
        sourceRoot: src,
        output: File('${tempDir.path}/ns.db'),
      ),
      throwsA(isA<SourceFormatException>()),
    );
  });

  test('unknown hadith slug throws', () {
    final src = Directory('${tempDir.path}/src')..createSync();
    copyDir(fixtureDir(''), src);
    File('${src.path}/hadith/unknown.json').writeAsStringSync('[]');
    expect(
      () =>
          buildContentDb(sourceRoot: src, output: File('${tempDir.path}/o.db')),
      throwsA(anything),
    );
  });

  test(
    'content version is schema:hash of final db, data_version from manifest',
    () {
      final bytes = File('${tempDir.path}/content.db').readAsBytesSync();
      expect(
        result.contentVersion,
        '2:${sha256.convert(bytes).toString().substring(0, 16)}',
      );
      final manifest = fixtureDir('').uri.resolve('CHECKSUMS.sha256');
      final want = sha256
          .convert(File.fromUri(manifest).readAsBytesSync())
          .toString()
          .substring(0, 16);
      expect(
        db
            .select("SELECT value FROM meta WHERE key='data_version'")
            .single
            .values
            .first,
        want,
      );
    },
  );

  test('two builds from same input are byte-identical', () {
    final a = buildFixtureDb(tempDir, 'a');
    final b = buildFixtureDb(tempDir, 'b');
    expect(b.bytes, a.bytes);
    expect(b.version, a.version);
    expect(
      buildFixtureDb(tempDir, 'c', changed: true).version,
      isNot(a.version),
    );
  });

  test('build is deterministic', () {
    final out2 = File('${tempDir.path}/b.db');
    buildContentDb(
      sourceRoot: fixtureDir(''),
      output: out2,
      builtAt: DateTime.utc(2026, 11, 9),
    );
    final db2 = sqlite3.open(out2.path, mode: OpenMode.readOnly);
    addTearDown(db2.dispose);
    for (final q in [
      'SELECT * FROM ayah ORDER BY id',
      'SELECT * FROM daily_hadith ORDER BY list, seq',
    ]) {
      expect(
        db2.select(q).map((r) => r.values).toList(),
        db.select(q).map((r) => r.values).toList(),
      );
    }
  });

  dailyTests();
}

// Daily content (spec 3.3).
void dailyTests() {
  late Directory tmp;

  setUp(() {
    tmp = Directory.systemTemp.createTempSync('nura_daily_');
    addTearDown(() => tmp.deleteSync(recursive: true));
  });

  Map<String, String?> books({Map<String, String?> extra = const {}}) => {
    'hadith/bukhari.json': hadithJson([
      goodHadith(1),
      narrativeHadith(2),
      goodHadith(3),
      goodHadith(4),
    ]),
    'hadith/muslim.json': hadithJson([goodHadith(1), goodHadith(2)]),
    'hadith/abu-daud.json': hadithJson([goodHadith(7), narrativeHadith(8)]),
    ...extra,
  };

  Database build(String name, Map<String, String?> files) {
    final out = File('${tmp.path}/$name.db');
    buildContentDb(
      sourceRoot: makeSource(tmp, '$name-src', files: files),
      output: out,
    );
    final d = sqlite3.open(out.path, mode: OpenMode.readOnly);
    addTearDown(d.dispose);
    return d;
  }

  List<Map<String, Object?>> rows(Database d, String list) => [
    for (final r in d.select(
      'SELECT d.*, h.book_slug, h.number, h.arab, h.translation_id '
      'FROM daily_hadith d JOIN hadith h ON h.id = d.hadith_id '
      'WHERE d.list = ? ORDER BY d.seq',
      [list],
    ))
      {...r},
  ];

  test(
    'default holds only qualifying Bukhari and Muslim, all holds 9 books',
    () {
      final d = build('a', books());
      final def = rows(d, 'default');
      final all = rows(d, 'all');
      expect(def.map((r) => '${r['book_slug']}:${r['number']}').toSet(), {
        'bukhari:1',
        'bukhari:3',
        'bukhari:4',
        'muslim:1',
        'muslim:2',
      });
      expect(all.length, 7); // plus fixture malik:4
      expect(all.map((r) => r['book_slug']).toSet(), contains('abu-daud'));
      for (final list in [def, all]) {
        expect(list.map((r) => r['seq']), [
          for (var i = 0; i < list.length; i++) i,
        ]);
      }
    },
  );

  test('stored offsets slice the original columns into the matan', () {
    final r = rows(build('a', books()), 'default').first;
    final arab = (r['arab'] as String).substring(
      r['arab_start'] as int,
      r['arab_end'] as int,
    );
    final tr = (r['translation_id'] as String).substring(
      r['tr_start'] as int,
      r['tr_end'] as int,
    );
    expect(arab, startsWith('مَنْ يَقُمْ'));
    expect(tr, startsWith('Barangsiapa menegakkan'));
  });

  test('lists are shuffled from (sort_order, number) with the fixed seed', () {
    final d = build('a', books());
    final ids = [
      for (final r in d.select(
        "SELECT h.id FROM hadith h JOIN hadith_book b ON b.slug = h.book_slug "
        "WHERE b.slug IN ('bukhari','muslim') ORDER BY b.sort_order, h.number",
      ))
        r['id'] as int,
    ]..removeWhere((id) => !rows(d, 'default').any((r) => r['hadith_id'] == id));
    expect(
      rows(d, 'default').map((r) => r['hadith_id']),
      seededShuffle(ids, dailySeed),
    );
  });

  test('two builds are byte-identical', () {
    build('a', books());
    build('b', books());
    expect(
      File('${tmp.path}/b.db').readAsBytesSync(),
      File('${tmp.path}/a.db').readAsBytesSync(),
    );
  });

  test('truncated hadith never qualify', () {
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
    final d = build(
      'a',
      books(
        extra: {
          'hadith/bukhari.json': hadithJson([goodHadith(1), cut]),
        },
      ),
    );
    expect(
      rows(d, 'default').map((r) => r['number']).toSet().contains(50),
      isFalse,
    );
    expect(
      rows(d, 'default').where((r) => r['book_slug'] == 'bukhari').length,
      1,
    );
  });

  group('daily_hadith_exclude.json', () {
    test('listed hadith are in neither list', () {
      final d = build(
        'a',
        books(
          extra: {
            'meta/daily_hadith_exclude.json':
                '[{"book":"bukhari","number":1},{"book":"abu-daud","number":7}]',
          },
        ),
      );
      for (final list in ['default', 'all']) {
        final keys = rows(
          d,
          list,
        ).map((r) => '${r['book_slug']}:${r['number']}');
        expect(keys, isNot(contains('bukhari:1')));
        expect(keys, isNot(contains('abu-daud:7')));
      }
      expect(rows(d, 'default').length, 4);
    });

    test('empty list or missing file excludes nothing', () {
      final plain = build('a', books());
      final empty = build(
        'b',
        books(extra: {'meta/daily_hadith_exclude.json': '[]'}),
      );
      expect(rows(empty, 'default').length, rows(plain, 'default').length);
      expect(rows(plain, 'all').length, 7);
    });

    test('an entry missing from the source fails the build clearly', () {
      expect(
        () => build(
          'a',
          books(
            extra: {
              'meta/daily_hadith_exclude.json':
                  '[{"book":"bukhari","number":99999}]',
            },
          ),
        ),
        throwsA(
          isA<SourceFormatException>().having(
            (e) => e.message,
            'message',
            contains('bukhari 99999'),
          ),
        ),
      );
      expect(
        () => build(
          'b',
          books(
            extra: {'meta/daily_hadith_exclude.json': '[{"book":"bukhari"}]'},
          ),
        ),
        throwsA(isA<SourceFormatException>()),
      );
    });
  });

  group('daily_ayah.json', () {
    String idsFor(Database d) => d
        .select('SELECT ayah_id FROM daily_ayah ORDER BY seq')
        .map((r) => r['ayah_id'])
        .join(',');

    test('valid pairs fill daily_ayah in seeded shuffle order', () {
      final d = build('a', {
        'meta/daily_ayah.json': '[{"surah":1,"ayah":2},{"surah":1,"ayah":3}]',
      });
      final a2 =
          d
                  .select(
                    'SELECT id FROM ayah WHERE surah_number=1 AND ayah_number=2',
                  )
                  .single['id']
              as int;
      final a3 =
          d
                  .select(
                    'SELECT id FROM ayah WHERE surah_number=1 AND ayah_number=3',
                  )
                  .single['id']
              as int;
      expect(idsFor(d), seededShuffle([a2, a3], dailySeed).join(','));
    });

    test('missing file gives an empty table', () {
      expect(idsFor(build('a', {})), '');
    });

    for (final bad in {
      'unknown pair': '[{"surah":1,"ayah":99}]',
      'duplicate': '[{"surah":1,"ayah":2},{"surah":1,"ayah":2}]',
      'string number': '[{"surah":"1","ayah":2}]',
      'missing key': '[{"surah":1}]',
      'not an object': '[1]',
      'not a list': '{"surah":1}',
    }.entries) {
      test('${bad.key} fails the build with a clear message', () {
        expect(
          () => build('a', {'meta/daily_ayah.json': bad.value}),
          throwsA(
            isA<SourceFormatException>().having(
              (e) => e.file,
              'file',
              'meta/daily_ayah.json',
            ),
          ),
        );
      });
    }
  });
}
