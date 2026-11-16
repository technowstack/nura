import 'dart:io';

import 'package:nura/content_pipeline/content_schema.dart';
import 'package:nura/content_pipeline/seeded_shuffle.dart';
import 'package:sqlite3/sqlite3.dart';

const int _sampleCount = 50;
// Distinct from dailySeed so the review sample is not the first days' picks.
const int _defaultSeed = 20261115;

String? _opt(List<String> args, String name) {
  final i = args.indexOf(name);
  return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
}

/// Writes 50 deterministic random samples of the `default` daily hadith list
/// (Arabic matan, translation matan, reference) for the owner to review.
void main(List<String> args) {
  final dbPath = _opt(args, '--db') ?? 'assets/db/content.db';
  final outPath = _opt(args, '--out') ?? 'docs/review/matan-samples.md';
  final seedArg = _opt(args, '--seed');
  final seed = seedArg == null ? _defaultSeed : int.tryParse(seedArg);
  if (seed == null) {
    stderr.writeln('error: --seed needs an integer, got "$seedArg"');
    exit(1);
  }
  final db = sqlite3.open(dbPath, mode: OpenMode.readOnly);
  try {
    final rows = db
        .select(
          'SELECT d.arab_start, d.arab_end, d.tr_start, d.tr_end, '
          'h.book_slug, h.number, h.arab, h.translation_id '
          'FROM daily_hadith d JOIN hadith h ON h.id = d.hadith_id '
          "WHERE d.list = 'default' ORDER BY d.seq",
        )
        .toList();
    final picked = seededShuffle(rows, seed).take(_sampleCount);
    final out = StringBuffer()
      ..writeln('# Sampel matan hadis harian')
      ..writeln()
      ..writeln(
        '$_sampleCount sampel acak (seed $seed) dari daftar `default` '
        '(Bukhari dan Muslim, ${rows.length} hadis), dihasilkan oleh '
        '`dart run tool/sample_daily_hadith.dart --seed $seed`. Periksa '
        'apakah matan Arab dan terjemahan sejajar dan utuh.',
      )
      ..writeln()
      ..writeln(
        'Aturan matan (spec 8.1): terjemahan = isi kutipan setelah '
        '`bersabda:`, tanpa tanda kutip lain di dalamnya (satu kutipan utuh, '
        'bukan dialog atau komentar), tanpa `[` `]`, tanpa "bersabda:" kedua, '
        'paling banyak 300 karakter; Arab = teks sesudah `صلى الله عليه وسلم` '
        '(dan kata kerja ucap) sampai akhir, paling banyak 300 karakter; '
        'rasio panjang terjemahan/Arab 0,8 sampai 3,0; 19 hadis terpotong dan '
        'daftar pengecualian manual dilewati.',
      );
    var n = 0;
    for (final r in picked) {
      final arab = (r['arab'] as String).substring(
        r['arab_start'] as int,
        r['arab_end'] as int,
      );
      final tr = (r['translation_id'] as String).substring(
        r['tr_start'] as int,
        r['tr_end'] as int,
      );
      final ref = 'HR. ${hadithBookNames[r['book_slug']]} No. ${r['number']}';
      out
        ..writeln()
        ..writeln('## ${++n}. $ref')
        ..writeln()
        ..writeln('Arab: $arab')
        ..writeln()
        ..writeln('Terjemahan: $tr');
    }
    File(outPath)
      ..parent.createSync(recursive: true)
      ..writeAsStringSync(out.toString());
    stdout.writeln('wrote $n samples to $outPath');
  } on Object catch (e) {
    stderr.writeln('error: $e');
    exit(1);
  } finally {
    db.dispose();
  }
}
