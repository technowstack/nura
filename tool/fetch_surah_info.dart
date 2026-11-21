import 'dart:convert';
import 'dart:io';

import 'package:nura/content_pipeline/quran_source_parser.dart';

import 'http_get_text.dart';

final surahInfoSourceUrl = Uri.parse('https://equran.id/api/v2/surat');

const _placeOf = {'Mekah': 'makkiyah', 'Madinah': 'madaniyah'};

/// `{number, revelation}` for all 114 surahs from an equran.id `/surat`
/// body. Any unknown place, missing/duplicate surah, count != 114 or
/// `jumlahAyat` differing from [ayahCounts] throws [FormatException].
List<Map<String, Object>> parseSurahInfo(
  String body,
  Map<int, int> ayahCounts,
) {
  final Object? json = jsonDecode(body);
  final data = json is Map<String, dynamic> ? json['data'] : null;
  if (data is! List<dynamic>) throw const FormatException('no data list');
  final byNumber = <int, String>{};
  for (final e in data) {
    if (e is! Map<String, dynamic>) throw FormatException('bad entry: $e');
    final n = e['nomor'];
    final place = _placeOf[e['tempatTurun']];
    if (n is! int || n < 1 || n > 114) throw FormatException('bad nomor: $n');
    if (place == null) {
      throw FormatException(
        'surah $n: unknown tempatTurun ${e['tempatTurun']}',
      );
    }
    if (e['jumlahAyat'] != ayahCounts[n]) {
      throw FormatException(
        'surah $n: jumlahAyat ${e['jumlahAyat']} != ${ayahCounts[n]}',
      );
    }
    if (byNumber.containsKey(n)) throw FormatException('duplicate surah $n');
    byNumber[n] = place;
  }
  if (byNumber.length != 114) {
    throw FormatException('expected 114 surahs, got ${byNumber.length}');
  }
  // Keys are unique and within 1..114, and there are 114 of them.
  return [
    for (final e
        in byNumber.entries.toList()..sort((a, b) => a.key.compareTo(b.key)))
      {'number': e.key, 'revelation': e.value},
  ];
}

Future<int> fetchSurahInfo({
  required Uri url,
  required File out,
  required Map<int, int> ayahCounts,
  Duration? timeout,
  DateTime? now,
}) async {
  final List<Map<String, Object>> surahs;
  try {
    surahs = parseSurahInfo(
      await httpGetText(url, timeout: timeout),
      ayahCounts,
    );
  } on Object catch (e) {
    stderr.writeln('error: $e');
    return 1;
  }
  out.parent.createSync(recursive: true);
  out.writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert({'source': url.toString(), 'fetched_at': (now ?? DateTime.now()).toUtc().toIso8601String(), 'surahs': surahs})}\n',
  );
  final mak = surahs.where((s) => s['revelation'] == 'makkiyah').length;
  stdout.writeln('makkiyah=$mak madaniyah=${surahs.length - mak}');
  return 0;
}

Future<void> main(List<String> args) async {
  final i = args.indexOf('--out');
  final out = File(
    i >= 0 && i + 1 < args.length
        ? args[i + 1]
        : 'data-source/meta/surah_info.json',
  );
  final counts = {
    for (final s in readQuranDir(Directory('data-source/quran')))
      s.number: s.ayahCount,
  };
  exit(
    await fetchSurahInfo(url: surahInfoSourceUrl, out: out, ayahCounts: counts),
  );
}
