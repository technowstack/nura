import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'checksum_manifest.dart';
import 'content_schema.dart';
import 'content_version.dart';
import 'expected_totals.dart';
import 'hadith_source_parser.dart';
import 'quran_source_parser.dart';
import 'text_normalizer.dart';
import 'verification_report.dart';

export 'expected_totals.dart';
export 'verification_report.dart';

int _count(Database db, String sql, [List<Object?> params = const []]) =>
    db.select(sql, params).single.values.first as int;

/// Checks [database] against the source JSON under [sourceRoot] (spec 3.4).
VerificationReport verifyContentDb({
  required Directory sourceRoot,
  required File database,
  ExpectedTotals? expected,
  File? versionFile,
}) {
  final report = VerificationReport();
  final errors = report.errors;

  // 1. Source checksums.
  final manifestFile = File('${sourceRoot.path}/CHECKSUMS.sha256');
  ChecksumManifest? manifest;
  if (!manifestFile.existsSync()) {
    errors.add('missing CHECKSUMS.sha256');
  } else {
    manifest = ChecksumManifest.parse(manifestFile.readAsStringSync());
    errors.addAll(manifest.verify(sourceRoot));
  }

  final surahs = readQuranDir(Directory('${sourceRoot.path}/quran'));
  final books = readHadithDir(Directory('${sourceRoot.path}/hadith'));
  final db = sqlite3.open(database.path, mode: OpenMode.readOnly);
  try {
    // 2. Row counts.
    void total(String what, int actual, int want) {
      if (actual != want) errors.add('$what count $actual != $want');
    }

    total('surah', _count(db, 'SELECT COUNT(*) FROM surah'), surahs.length);
    total(
      'ayah',
      _count(db, 'SELECT COUNT(*) FROM ayah'),
      surahs.fold(0, (n, s) => n + s.ayahs.length),
    );
    total(
      'hadith_book',
      _count(db, 'SELECT COUNT(*) FROM hadith_book'),
      books.length,
    );
    total(
      'hadith',
      _count(db, 'SELECT COUNT(*) FROM hadith'),
      books.fold(0, (n, b) => n + b.hadiths.length),
    );
    final juzFile = File('${sourceRoot.path}/meta/juz.json');
    if (juzFile.existsSync()) {
      final juz = _count(db, 'SELECT COUNT(*) FROM juz');
      total('juz', juz, expected == null ? juz : 30);
    }
    if (expected != null) {
      total('expected surah', surahs.length, expected.surahs);
      total(
        'expected ayah',
        _count(db, 'SELECT COUNT(*) FROM ayah'),
        expected.ayahs,
      );
      total('expected hadith_book', books.length, expected.books);
      total(
        'expected hadith',
        _count(db, 'SELECT COUNT(*) FROM hadith'),
        expected.hadiths,
      );
    }

    // 3 + 4. Row-by-row full-string comparison.
    final surahRows = {
      for (final r in db.select('SELECT * FROM surah')) r['number'] as int: r,
    };
    final ayahRows = {
      for (final r in db.select('SELECT * FROM ayah'))
        '${r['surah_number']}:${r['ayah_number']}': r,
    };
    for (final s in surahs) {
      final sr = surahRows[s.number];
      if (sr == null) {
        errors.add('missing surah ${s.number}');
      } else {
        final stored = _count(
          db,
          'SELECT COUNT(*) FROM ayah WHERE surah_number = ?',
          [s.number],
        );
        if (sr['ayah_count'] != stored || stored != s.ayahCount) {
          errors.add(
            'surah ${s.number} ayah_count ${sr['ayah_count']} != $stored rows',
          );
        }
        final rev = sr['revelation'] as String;
        if (rev.isEmpty) {
          report.warnings.add('surah ${s.number}: empty revelation');
        }
      }
      for (final a in s.ayahs) {
        final key = '${s.number}:${a.number}';
        final r = ayahRows[key];
        if (r == null) {
          errors.add('missing ayah $key');
          continue;
        }
        if (r['arab'] != a.arab) errors.add('ayah $key arab differs');
        if (r['translation_id'] != a.translation) {
          errors.add('ayah $key translation_id differs');
        }
        if (r['tafsir_kemenag'] != a.tafsir) {
          errors.add('ayah $key tafsir_kemenag differs');
        }
      }
    }
    final hadithRows = {
      for (final r in db.select('SELECT * FROM hadith'))
        '${r['book_slug']}:${r['number']}': r,
    };
    for (final b in books) {
      final counts = db.select(
        'SELECT hadith_count FROM hadith_book WHERE slug = ?',
        [b.slug],
      );
      if (counts.isEmpty) {
        errors.add('missing hadith_book ${b.slug}');
      } else if (counts.single['hadith_count'] != b.hadiths.length) {
        errors.add('hadith_book ${b.slug} hadith_count differs');
      }
      for (final h in b.hadiths) {
        final key = '${b.slug}:${h.number}';
        final r = hadithRows[key];
        if (r == null) {
          errors.add('missing hadith $key');
          continue;
        }
        if (r['arab'] != h.arab) errors.add('hadith $key arab differs');
        if (r['translation_id'] != h.translation) {
          errors.add('hadith $key translation_id differs');
        }
        // UTF-16 code units, same as the builder.
        if (r['translation_length'] != h.translation.length) {
          errors.add('hadith $key translation_length differs');
        }
      }
    }

    // 5. FTS. Contentless tables cannot be read back or integrity-checked,
    // so compare index size to the main table and probe with real words.
    void checkFts(
      String table,
      String where,
      List<Object?> params,
      String arab,
      String text,
    ) {
      final fts = '${table}_fts';
      final id = _count(db, 'SELECT id FROM $table WHERE $where', params);
      total(
        fts,
        _count(db, 'SELECT COUNT(*) FROM ${fts}_docsize'),
        _count(db, 'SELECT COUNT(*) FROM $table'),
      );
      // A word of the probe row's normalized text must find that row's id.
      final probes = {
        'arab': (normalizeArabicForSearch(arab).split(' '), 'arab'),
        'translation': (
          normalizeIndonesianForSearch(text).split(' '),
          'translation',
        ),
      };
      for (final p in probes.values) {
        final word = p.$1.firstWhere((w) => w.isNotEmpty, orElse: () => '');
        if (word.isEmpty) continue;
        final hits = db.select('SELECT rowid FROM $fts WHERE $fts MATCH ?', [
          '${p.$2}:"$word"',
        ]);
        if (!hits.any((r) => r['rowid'] == id)) {
          errors.add('$fts MATCH ${p.$2}:"$word" does not find rowid $id');
        }
      }
    }

    if (surahs.isNotEmpty && surahs.first.ayahs.isNotEmpty) {
      final a = surahs.first.ayahs.first;
      checkFts(
        'ayah',
        'surah_number = ? AND ayah_number = ?',
        [surahs.first.number, a.number],
        a.arab,
        a.translation,
      );
    }
    if (books.isNotEmpty && books.first.hadiths.isNotEmpty) {
      final h = books.first.hadiths.first;
      checkFts(
        'hadith',
        'book_slug = ? AND number = ?',
        [books.first.slug, h.number],
        h.arab,
        h.translation,
      );
    }

    // 6. meta.source_checksums.
    final meta = db.select(
      "SELECT value FROM meta WHERE key = 'source_checksums'",
    );
    if (meta.isEmpty) {
      errors.add('meta.source_checksums missing');
    } else if (manifest != null && meta.single['value'] != manifest.toJson()) {
      errors.add('meta.source_checksums differs from CHECKSUMS.sha256');
    }
  } finally {
    db.dispose();
  }

  // 7. content.version sidecar matches the final db file.
  if (versionFile != null) {
    final want = contentVersionOf(database, contentSchemaVersion);
    if (!versionFile.existsSync()) {
      errors.add('missing content.version');
    } else if (versionFile.readAsStringSync().trim() != want) {
      errors.add('content.version does not match db (expected $want)');
    }
  }
  return report;
}
