import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:nura/content_pipeline/content_db_builder.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

import '../support/fixtures.dart';

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
      dataVersion: 'test-1',
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
    expect(m['schema_version'], '1');
    expect(m['data_version'], 'test-1');
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

  test('daily_hadith contains only hadith with translation_length <= 400', () {
    expect(count('daily_hadith'), greaterThan(0));
    expect(
      db.select(
        'SELECT 1 FROM daily_hadith d JOIN hadith h ON h.id=d.hadith_id '
        'WHERE h.translation_length > 400',
      ),
      isEmpty,
    );
    expect(
      count('daily_hadith'),
      db
          .select(
            'SELECT COUNT(*) c FROM hadith WHERE translation_length <= 400',
          )
          .single['c'],
    );
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
    buildContentDb(sourceRoot: src, output: out, dataVersion: 'x');
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
        dataVersion: 'x',
      ),
      throwsA(anything),
    );
    expect(File('${tempDir.path}/o3.db').existsSync(), isFalse);
  });

  test('unknown hadith slug throws', () {
    final src = Directory('${tempDir.path}/src')..createSync();
    copyDir(fixtureDir(''), src);
    File('${src.path}/hadith/unknown.json').writeAsStringSync('[]');
    expect(
      () => buildContentDb(
        sourceRoot: src,
        output: File('${tempDir.path}/o.db'),
        dataVersion: 'x',
      ),
      throwsA(anything),
    );
  });

  test('build is deterministic', () {
    final out2 = File('${tempDir.path}/b.db');
    buildContentDb(
      sourceRoot: fixtureDir(''),
      output: out2,
      dataVersion: 'test-1',
      builtAt: DateTime.utc(2026, 11, 9),
    );
    final db2 = sqlite3.open(out2.path, mode: OpenMode.readOnly);
    addTearDown(db2.dispose);
    for (final q in [
      'SELECT * FROM ayah ORDER BY id',
      'SELECT * FROM daily_hadith ORDER BY seq',
    ]) {
      expect(
        db2.select(q).map((r) => r.values).toList(),
        db.select(q).map((r) => r.values).toList(),
      );
    }
  });
}
