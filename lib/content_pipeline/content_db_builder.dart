import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'build_result.dart';
import 'checksum_manifest.dart';
import 'content_schema.dart';
import 'hadith_source_parser.dart';
import 'quran_source_parser.dart';
import 'seeded_shuffle.dart';
import 'source_models.dart';
import 'text_normalizer.dart';

export 'build_result.dart';

List<Map<String, dynamic>>? _optionalList(Directory root, String name) {
  final f = File('${root.path}/meta/$name');
  if (!f.existsSync()) return null;
  try {
    return (jsonDecode(f.readAsStringSync()) as List<dynamic>).cast<Map<String, dynamic>>();
  } on Object catch (e) {
    throw SourceFormatException('meta/$name', 'invalid json: $e');
  }
}

BuildResult buildContentDb({
  required Directory sourceRoot,
  required File output,
  required String dataVersion,
  DateTime? builtAt,
}) {
  final warnings = <String>[];
  final surahs = readQuranDir(Directory('${sourceRoot.path}/quran'));
  final books = readHadithDir(Directory('${sourceRoot.path}/hadith'));
  final order = hadithBookNames.keys.toList();
  for (final b in books) {
    if (!hadithBookNames.containsKey(b.slug)) {
      throw SourceFormatException(b.slug, 'unknown hadith book slug');
    }
  }
  books.sort((a, b) => order.indexOf(a.slug).compareTo(order.indexOf(b.slug)));

  final info = <int, String>{
    for (final e in _optionalList(sourceRoot, 'surah_info.json') ?? const [])
      e['number'] as int: e['revelation'] as String,
  };
  final manifestFile = File('${sourceRoot.path}/CHECKSUMS.sha256');
  final checksums = manifestFile.existsSync()
      ? ChecksumManifest.parse(manifestFile.readAsStringSync()).toJson()
      : '{}';

  final tmp = File('${output.path}.tmp');
  if (tmp.existsSync()) tmp.deleteSync();
  final db = sqlite3.open(tmp.path);
  var ayahCount = 0;
  var hadithCount = 0;
  try {
    db.execute('BEGIN');
    contentSchemaDdl.forEach(db.execute);

    final meta = db.prepare('INSERT INTO meta(key, value) VALUES (?, ?)');
    for (final kv in {
      'schema_version': '$contentSchemaVersion',
      'data_version': dataVersion,
      'built_at': (builtAt ?? DateTime.now()).toUtc().toIso8601String(),
      'source_checksums': checksums,
    }.entries) {
      meta.execute([kv.key, kv.value]);
    }
    meta.dispose();

    final insSurah = db.prepare('INSERT INTO surah VALUES (?, ?, ?, ?, ?, ?)');
    final insAyah = db.prepare('INSERT INTO ayah VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    final ayahIds = <String, int>{};
    for (final s in surahs) {
      final rev = info[s.number] ?? '';
      if (rev.isEmpty) {
        warnings.add('surah ${s.number}: no revelation in meta/surah_info.json');
      } else if (rev != 'makkiyah' && rev != 'madaniyah') {
        warnings.add('surah ${s.number}: unexpected revelation "$rev"');
      }
      insSurah.execute([s.number, s.nameArab, s.nameLatin, s.nameId, s.ayahCount, rev]);
      for (final a in s.ayahs) {
        ayahCount++;
        ayahIds['${s.number}:${a.number}'] = ayahCount;
        insAyah.execute([
          ayahCount, s.number, a.number, a.arab, a.translation, a.tafsir,
          normalizeArabicForSearch(a.arab),
          normalizeIndonesianForSearch(a.translation),
        ]);
      }
    }
    insSurah.dispose();
    insAyah.dispose();

    final insBook = db.prepare('INSERT INTO hadith_book VALUES (?, ?, ?, ?)');
    final insHadith = db.prepare('INSERT INTO hadith VALUES (?, ?, ?, ?, ?, ?, ?, ?)');
    final dailyCandidates = <int>[];
    for (final b in books) {
      insBook.execute([b.slug, hadithBookNames[b.slug], b.hadiths.length, order.indexOf(b.slug)]);
      for (final h in b.hadiths) {
        hadithCount++;
        final len = h.translation.length;
        if (len <= dailyHadithMaxLength) dailyCandidates.add(hadithCount);
        insHadith.execute([
          hadithCount, b.slug, h.number, h.arab, h.translation,
          normalizeArabicForSearch(h.arab),
          normalizeIndonesianForSearch(h.translation),
          len,
        ]);
      }
    }
    insBook.dispose();
    insHadith.dispose();

    final insJuz = db.prepare('INSERT INTO juz VALUES (?, ?, ?, ?, ?)');
    for (final j in _optionalList(sourceRoot, 'juz.json') ?? const []) {
      insJuz.execute([
        j['number'], j['start_surah'], j['start_ayah'], j['end_surah'], j['end_ayah'],
      ]);
    }
    insJuz.dispose();

    final dailyAyah = _optionalList(sourceRoot, 'daily_ayah.json') ?? const [];
    final ids = [
      for (final e in dailyAyah)
        ayahIds['${e['surah']}:${e['ayah']}'] ??
            (throw SourceFormatException(
                'meta/daily_ayah.json', 'no such ayah ${e['surah']}:${e['ayah']}')),
    ];
    final insDa = db.prepare('INSERT INTO daily_ayah VALUES (?, ?)');
    final shuffledAyah = seededShuffle(ids, dailySeed);
    for (var i = 0; i < shuffledAyah.length; i++) {
      insDa.execute([i, shuffledAyah[i]]);
    }
    insDa.dispose();

    final insDh = db.prepare('INSERT INTO daily_hadith VALUES (?, ?)');
    final shuffledHadith = seededShuffle(dailyCandidates, dailySeed);
    for (var i = 0; i < shuffledHadith.length; i++) {
      insDh.execute([i, shuffledHadith[i]]);
    }
    insDh.dispose();

    db.execute("INSERT INTO ayah_fts(ayah_fts) VALUES('rebuild')");
    db.execute("INSERT INTO hadith_fts(hadith_fts) VALUES('rebuild')");
    db.execute('COMMIT');
    db.execute('VACUUM');
    db.dispose();
    tmp.renameSync(output.path);
  } on Object {
    db.dispose();
    if (tmp.existsSync()) tmp.deleteSync();
    rethrow;
  }
  return BuildResult(
    surahCount: surahs.length,
    ayahCount: ayahCount,
    hadithCount: hadithCount,
    warnings: warnings,
  );
}
