import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/search_snippet.dart';
import 'package:nura/content_pipeline/text_normalizer.dart';
import 'package:sqlite3/sqlite3.dart';

// Real texts from the generated content.db (run tool/prepare_content.sh first).
late Database _db;

String _ayah(int surah, int ayah) =>
    _db.select(
          'SELECT arab FROM ayah WHERE surah_number = ? AND ayah_number = ?',
          [surah, ayah],
        ).first['arab']
        as String;

String _hadith(String book, int number) =>
    _db.select('SELECT arab FROM hadith WHERE book_slug = ? AND number = ?', [
          book,
          number,
        ]).first['arab']
        as String;

List<String> _highlighted(Snippet s) => [
  for (final h in s.highlights) s.text.substring(h.start, h.end),
];

void main() {
  setUpAll(() {
    _db = sqlite3.open('assets/db/content.db', mode: OpenMode.readOnly);
  });
  tearDownAll(() => _db.dispose());

  test('(a) basmalah: الرحمن covers the vocalized word exactly', () {
    final text = _ayah(1, 1);
    final s = buildArabicSnippet(text, ['الرحمن']);
    expect(s.text, text);
    expect(_highlighted(s), [text.split(' ')[2]]);
    expect(normalizeArabicForSearch(_highlighted(s).single), 'الرحمن');
    expect(s.cutStart || s.cutEnd, isFalse);
  });

  test('(b) token split by shadda and dagger alif', () {
    final text = _ayah(1, 1);
    final s = buildArabicSnippet(text, ['الله']);
    expect(_highlighted(s), ['اللّٰهِ']);
  });

  test(
    '(c) alif, alif maqsura and ta marbuta map back to original letters',
    () {
      final text = _hadith('ahmad', 15666);
      final s = buildArabicSnippet(text, ['ادم', 'الي', 'امر', 'الساعه']);
      final w = text.split(' ');
      expect(_highlighted(s), [w[12], w[13], w[15], w[16]]);
      expect(w[12].startsWith('آ') && w[13].startsWith('إ'), isTrue);
      expect(w[15].contains('ة') && w[16].startsWith('أ'), isTrue);

      final wasla = buildArabicSnippet('بِسْمِ ٱللَّهِ', ['الله']);
      expect(_highlighted(wasla), ['ٱللَّهِ']);
    },
  );

  test('(d) waqf mark and tatweel inside a word are inside the range', () {
    final fatihah7 = _ayah(1, 7);
    final word = fatihah7.split(' ')[9];
    expect(word.contains('\u06E4'), isTrue);
    expect(_highlighted(buildArabicSnippet(fatihah7, ['الضالين'])), [word]);

    final baqarah189 = _ayah(2, 189);
    final yasalunaka = baqarah189.split(' ')[1];
    expect(yasalunaka.contains('\u0640'), isTrue);
    expect(_highlighted(buildArabicSnippet(baqarah189, ['يسلونك'])), [
      yasalunaka,
    ]);

    // Trailing waqf mark after the last letter is absorbed too.
    final najm15 = _ayah(53, 15);
    expect(_highlighted(buildArabicSnippet(najm15, ['الماوي'])), [
      'الْمَأْوٰىۗ',
    ]);
  });

  test('(e) long hadith: 100-char window on the original text', () {
    final text = _hadith('muslim', 4973);
    expect(text.length, greaterThan(8000));
    final norm = normalizeArabicForSearch(text);
    // A word whose first occurrence is in the second half of the text.
    final token = norm
        .split(' ')
        .firstWhere((w) => w.length >= 5 && norm.indexOf(w) > norm.length ~/ 2);
    final s = buildArabicSnippet(text, [token]);
    expect(s.text.length, lessThanOrEqualTo(100));
    expect(text.contains(s.text), isTrue);
    expect(s.cutStart, isTrue);
    expect(s.highlights, isNotEmpty);
    for (final h in _highlighted(s)) {
      expect(normalizeArabicForSearch(h), contains(token));
    }
  });

  test('(f) no occurrence falls back to the text start', () {
    final text = _hadith('muslim', 4973);
    final s = buildArabicSnippet(text, ['ززززز']);
    expect(s.highlights, isEmpty);
    expect(s.cutStart, isFalse);
    expect(s.cutEnd, isTrue);
    expect(s.text, isNotEmpty);
    expect(text.startsWith(s.text), isTrue);
  });

  test('offset map normalization equals the index normalizer', () {
    final samples = [
      for (final r in _db.select(
        'SELECT arab FROM ayah WHERE id % 250 = 0 LIMIT 25',
      ))
        r['arab'] as String,
      for (final r in _db.select(
        'SELECT arab FROM hadith WHERE id % 1500 = 0 LIMIT 25',
      ))
        r['arab'] as String,
      _ayah(53, 15),
      ' َ  ب \n',
    ];
    expect(samples.length, greaterThanOrEqualTo(50));
    for (final text in samples) {
      final n = normalizeArabicWithOffsets(text);
      expect(n.text, normalizeArabicForSearch(text));
      expect(n.offsets.length, n.text.length);
    }
  });
}
