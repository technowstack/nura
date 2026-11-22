import 'dart:convert';
import 'dart:io';

import 'package:nura/app/core/format_thousands.dart';
import 'package:sqlite3/sqlite3.dart';

/// Real content only: book names from `hadithBookNames`, counts from
/// data-source/README.md, texts from data-source/hadith/*.json.
const kitab = <(String, String, int)>[
  ('bukhari', 'Shahih Bukhari', 6638),
  ('muslim', 'Shahih Muslim', 4930),
  ('abu-daud', 'Sunan Abu Daud', 4419),
  ('tirmidzi', 'Sunan Tirmidzi', 3625),
  ('nasai', "Sunan Nasa'i", 5364),
  ('ibnu-majah', 'Sunan Ibnu Majah', 4285),
  ('ahmad', 'Musnad Ahmad', 4305),
  ('malik', "Muwatha' Malik", 1587),
  ('darimi', 'Sunan Darimi', 2949),
];

String countLabel(int n) => '${formatThousands(n)} hadis';

class RealHadith {
  const RealHadith(this.number, this.arab, this.translation);
  final int number;
  final String arab;
  final String translation;

  /// First 200 code points, as HadithSummary.preview.
  String get preview => String.fromCharCodes(translation.runes.take(200));
}

List<RealHadith> loadBukhari() {
  final raw =
      jsonDecode(File('data-source/hadith/bukhari.json').readAsStringSync())
          as List<dynamic>;
  return [
    for (final e in raw)
      RealHadith(
        (e as Map<String, dynamic>)['number'] as int,
        e['arab'] as String,
        e['id'] as String,
      ),
  ];
}

/// Real daily hadith slice (same offsets as SqliteDailyContentRepository).
({String arab, String tr, String ref}) loadDaily() {
  final db = sqlite3.open('assets/db/content.db', mode: OpenMode.readOnly);
  try {
    final r = db
        .select(
          'SELECT h.book_slug, h.number, h.arab, h.translation_id, '
          'd.arab_start, d.arab_end, d.tr_start, d.tr_end FROM daily_hadith d '
          "JOIN hadith h ON h.id = d.hadith_id WHERE d.list='default' AND d.seq=4",
        )
        .single;
    final a = r['arab'] as String;
    final t = r['translation_id'] as String;
    return (
      arab: a.substring(r['arab_start'] as int, r['arab_end'] as int),
      tr: t.substring(r['tr_start'] as int, r['tr_end'] as int),
      ref: 'HR. Muslim No. ${r['number']}',
    );
  } finally {
    db.dispose();
  }
}
