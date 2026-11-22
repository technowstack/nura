/// One juz as stored in `meta/juz.json` and the `juz` table.
class JuzRange {
  const JuzRange(
    this.number,
    this.startSurah,
    this.startAyah,
    this.endSurah,
    this.endAyah,
  );

  final int number;
  final int startSurah;
  final int startAyah;
  final int endSurah;
  final int endAyah;

  Map<String, int> toJson() => {
    'number': number,
    'start_surah': startSurah,
    'start_ayah': startAyah,
    'end_surah': endSurah,
    'end_ayah': endAyah,
  };
}

/// Juz boundaries checked by [validateJuz] (number: start surah, start ayah).
const juzReferenceStarts = {2: (2, 142), 15: (17, 1), 30: (78, 1)};

/// Builds 30 juz from their start points; each ends just before the next
/// start, the last at the end of the final surah. Throws [FormatException].
List<JuzRange> buildJuz(List<(int, int)> starts, Map<int, int> ayahCounts) {
  final juz = <JuzRange>[];
  final last = ayahCounts.keys.reduce((a, b) => a > b ? a : b);
  for (var i = 0; i < starts.length; i++) {
    final (s, a) = starts[i];
    final (es, ea) = i + 1 < starts.length
        ? _before(starts[i + 1], ayahCounts)
        : (last, ayahCounts[last] ?? 0);
    juz.add(JuzRange(i + 1, s, a, es, ea));
  }
  final errors = validateJuz(juz, ayahCounts, expectedCount: 30);
  if (errors.isNotEmpty) throw FormatException(errors.join('; '));
  return juz;
}

(int, int) _before((int, int) start, Map<int, int> counts) {
  final (s, a) = start;
  if (a > 1) return (s, a - 1);
  return (s - 1, counts[s - 1] ?? 0);
}

/// Returns problems with [juz] against the ayah count of each surah. Checks
/// numbering, start/end validity, strictly increasing starts, no gap or
/// overlap, full coverage of every ayah in [ayahCounts] and the reference
/// starts. Empty when valid. [expectedCount] also fixes the number of juz.
List<String> validateJuz(
  List<JuzRange> juz,
  Map<int, int> ayahCounts, {
  int? expectedCount,
}) {
  final errors = <String>[];
  if (expectedCount != null && juz.length != expectedCount) {
    errors.add('juz count ${juz.length} != $expectedCount');
  }
  // Position of each ayah in reading order.
  final offset = <int, int>{};
  var total = 0;
  for (final s in ayahCounts.keys.toList()..sort()) {
    offset[s] = total;
    total += ayahCounts[s] ?? 0;
  }
  int? pos(int s, int a) {
    final n = ayahCounts[s];
    return n == null || a < 1 || a > n ? null : offset[s]! + a - 1;
  }

  var expectNext = 0;
  for (var i = 0; i < juz.length; i++) {
    final j = juz[i];
    if (j.number != i + 1) errors.add('juz #$i has number ${j.number}');
    final st = pos(j.startSurah, j.startAyah);
    final en = pos(j.endSurah, j.endAyah);
    if (st == null || en == null) {
      errors.add('juz ${j.number}: start or end is not a real ayah');
      continue;
    }
    if (en < st) errors.add('juz ${j.number}: ends before it starts');
    if (st != expectNext) {
      errors.add(
        'juz ${j.number}: starts at ${j.startSurah}:${j.startAyah}, '
        'expected ayah index $expectNext (gap or overlap)',
      );
    }
    expectNext = en + 1;
    final ref = juzReferenceStarts[j.number];
    if (ref != null && (j.startSurah, j.startAyah) != ref) {
      errors.add(
        'juz ${j.number} starts ${j.startSurah}:${j.startAyah}, '
        'expected ${ref.$1}:${ref.$2}',
      );
    }
  }
  if (juz.isNotEmpty && expectNext != total) {
    errors.add('juz cover $expectNext of $total ayat');
  }
  return errors;
}
