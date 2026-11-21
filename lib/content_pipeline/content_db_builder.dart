import 'dart:convert';
import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'build_result.dart';
import 'checksum_manifest.dart';
import 'content_schema.dart';
import 'content_version.dart';
import 'hadith_source_parser.dart';
import 'matan_extractor.dart';
import 'meta_lists.dart';
import 'quran_source_parser.dart';
import 'seeded_shuffle.dart';
import 'source_models.dart';
import 'text_normalizer.dart';

export 'build_result.dart';

/// Entries of `meta/[name]`: a plain json list, or an object (with `source`
/// and `fetched_at`) holding the list under [key].
List<Map<String, dynamic>>? _optionalList(
  Directory root,
  String name,
  String key,
) {
  final f = File('${root.path}/meta/$name');
  if (!f.existsSync()) return null;
  try {
    final json = jsonDecode(f.readAsStringSync());
    return ((json is Map<String, dynamic> ? json[key] : json) as List<dynamic>)
        .cast<Map<String, dynamic>>();
  } on Object catch (e) {
    throw SourceFormatException('meta/$name', 'invalid json: $e');
  }
}

const _ayahFile = 'meta/daily_ayah.json';

/// Ids of the daily ayah list, in file order. Rejects malformed entries,
/// pairs that do not exist and duplicates.
List<int> _dailyAyahIds(Directory root, Map<String, int> ayahIds) {
  final seen = <String>{};
  final ids = <int>[];
  for (final e in readMetaObjects(root, _ayahFile)) {
    if (e['surah'] is! int || e['ayah'] is! int) {
      throw SourceFormatException(
        _ayahFile,
        'entry needs integer "surah" and "ayah": $e',
      );
    }
    final key = '${e['surah']}:${e['ayah']}';
    final id = ayahIds[key];
    if (id == null) throw SourceFormatException(_ayahFile, 'no such ayah $key');
    if (!seen.add(key)) {
      throw SourceFormatException(_ayahFile, 'duplicate ayah $key');
    }
    ids.add(id);
  }
  return ids;
}

class _DailyCandidate {
  _DailyCandidate(this.id, this.slug, this.sortOrder, this.number, this.matan);

  final int id;
  final String slug;
  final int sortOrder;
  final int number;
  final Matan matan;
}

BuildResult buildContentDb({
  required Directory sourceRoot,
  required File output,
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
    for (final e
        in _optionalList(sourceRoot, 'surah_info.json', 'surahs') ?? const [])
      e['number'] as int: e['revelation'] as String,
  };
  final manifestFile = File('${sourceRoot.path}/CHECKSUMS.sha256');
  if (!manifestFile.existsSync()) {
    throw SourceFormatException('CHECKSUMS.sha256', 'missing');
  }
  final checksums = ChecksumManifest.parse(
    manifestFile.readAsStringSync(),
  ).toJson();
  final dataVersion = shortSha256(manifestFile.readAsBytesSync());

  final tmp = File('${output.path}.tmp');
  if (tmp.existsSync()) tmp.deleteSync();
  final db = sqlite3.open(tmp.path);
  var ayahCount = 0;
  var hadithCount = 0;
  try {
    db.execute('PRAGMA page_size = 16384');
    db.execute('BEGIN');
    contentSchemaDdl.forEach(db.execute);

    final meta = db.prepare('INSERT INTO meta(key, value) VALUES (?, ?)');
    for (final kv in {
      'schema_version': '$contentSchemaVersion',
      'data_version': dataVersion,
      // Fixed default keeps the db byte-identical across builds.
      'built_at': (builtAt ?? DateTime.utc(1970)).toUtc().toIso8601String(),
      'source_checksums': checksums,
    }.entries) {
      meta.execute([kv.key, kv.value]);
    }
    meta.dispose();

    final insSurah = db.prepare('INSERT INTO surah VALUES (?, ?, ?, ?, ?, ?)');
    final insAyah = db.prepare('INSERT INTO ayah VALUES (?, ?, ?, ?, ?, ?)');
    final insAyahFts = db.prepare(
      'INSERT INTO ayah_fts(rowid, arab, translation) VALUES (?, ?, ?)',
    );
    final ayahIds = <String, int>{};
    for (final s in surahs) {
      final rev = info[s.number] ?? '';
      if (rev.isEmpty) {
        warnings.add(
          'surah ${s.number}: no revelation in meta/surah_info.json',
        );
      } else if (rev != 'makkiyah' && rev != 'madaniyah') {
        warnings.add('surah ${s.number}: unexpected revelation "$rev"');
      }
      insSurah.execute([
        s.number,
        s.nameArab,
        s.nameLatin,
        s.nameId,
        s.ayahCount,
        rev,
      ]);
      for (final a in s.ayahs) {
        ayahCount++;
        ayahIds['${s.number}:${a.number}'] = ayahCount;
        insAyah.execute([
          ayahCount,
          s.number,
          a.number,
          a.arab,
          a.translation,
          a.tafsir,
        ]);
        insAyahFts.execute([
          ayahCount,
          normalizeAyahArabicForIndex(a.arab),
          normalizeIndonesianForSearch(a.translation),
        ]);
      }
    }
    insSurah.dispose();
    insAyah.dispose();
    insAyahFts.dispose();

    final insBook = db.prepare('INSERT INTO hadith_book VALUES (?, ?, ?, ?)');
    final insHadith = db.prepare(
      'INSERT INTO hadith VALUES (?, ?, ?, ?, ?, ?)',
    );
    final insHadithFts = db.prepare(
      'INSERT INTO hadith_fts(rowid, arab, translation) VALUES (?, ?, ?)',
    );
    final excluded = readExcludedHadith(sourceRoot);
    final unmatchedExcluded = {...excluded};
    final dailyCandidates = <_DailyCandidate>[];
    for (final b in books) {
      insBook.execute([
        b.slug,
        hadithBookNames[b.slug],
        b.hadiths.length,
        order.indexOf(b.slug),
      ]);
      for (final h in b.hadiths) {
        hadithCount++;
        final len = h.translation.length;
        final key = '${b.slug}:${h.number}';
        unmatchedExcluded.remove(key);
        final isExcluded = excluded.contains(key);
        if (!isExcluded &&
            utf8.encode(h.arab).length < kSourceTruncationBytes &&
            utf8.encode(h.translation).length < kSourceTruncationBytes) {
          final matan = extractMatan(h.arab, h.translation);
          if (matan != null) {
            dailyCandidates.add(
              _DailyCandidate(
                hadithCount,
                b.slug,
                order.indexOf(b.slug),
                h.number,
                matan,
              ),
            );
          }
        }
        insHadith.execute([
          hadithCount,
          b.slug,
          h.number,
          h.arab,
          h.translation,
          len,
        ]);
        insHadithFts.execute([
          hadithCount,
          normalizeArabicForSearch(h.arab),
          normalizeIndonesianForSearch(h.translation),
        ]);
      }
    }
    insBook.dispose();
    insHadith.dispose();
    insHadithFts.dispose();

    final insJuz = db.prepare('INSERT INTO juz VALUES (?, ?, ?, ?, ?)');
    for (final j in _optionalList(sourceRoot, 'juz.json', 'juz') ?? const []) {
      insJuz.execute([
        j['number'],
        j['start_surah'],
        j['start_ayah'],
        j['end_surah'],
        j['end_ayah'],
      ]);
    }
    insJuz.dispose();

    final insDa = db.prepare('INSERT INTO daily_ayah VALUES (?, ?)');
    final shuffledAyah = seededShuffle(
      _dailyAyahIds(sourceRoot, ayahIds),
      dailySeed,
    );
    for (var i = 0; i < shuffledAyah.length; i++) {
      insDa.execute([i, shuffledAyah[i]]);
    }
    insDa.dispose();

    if (unmatchedExcluded.isNotEmpty) {
      throw SourceFormatException(
        excludedHadithFile,
        'not found in the source: ${(unmatchedExcluded.toList()..sort()).map((k) => k.replaceFirst(':', ' ')).join(', ')}',
      );
    }
    dailyCandidates.sort(
      (a, b) => a.sortOrder != b.sortOrder
          ? a.sortOrder.compareTo(b.sortOrder)
          : a.number.compareTo(b.number),
    );
    final insDh = db.prepare(
      'INSERT INTO daily_hadith VALUES (?, ?, ?, ?, ?, ?, ?)',
    );
    final defaultBooks = {'bukhari', 'muslim'};
    for (final list in ['default', 'all']) {
      final shuffled = seededShuffle([
        for (final c in dailyCandidates)
          if (list == 'all' || defaultBooks.contains(c.slug)) c,
      ], dailySeed);
      for (var i = 0; i < shuffled.length; i++) {
        final m = shuffled[i].matan;
        insDh.execute([
          list,
          i,
          shuffled[i].id,
          m.arabStart,
          m.arabEnd,
          m.trStart,
          m.trEnd,
        ]);
      }
    }
    insDh.dispose();

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
    contentVersion: contentVersionOf(output, contentSchemaVersion),
  );
}
