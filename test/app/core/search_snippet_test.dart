import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/search_snippet.dart';

const _baqarah45 =
    'Dan mohonlah pertolongan (kepada Allah) dengan sabar dan salat. Dan (salat) itu sungguh berat, kecuali bagi orang-orang yang khusyuk,';
const _baqarah153 =
    'Wahai orang-orang yang beriman! Mohonlah pertolongan (kepada Allah) dengan sabar dan salat. Sungguh, Allah beserta orang-orang yang sabar.';
const _ali146 =
    'Dan betapa banyak nabi yang berperang didampingi sejumlah besar dari pengikut(nya) yang bertakwa. Mereka tidak (menjadi) lemah karena bencana yang menimpanya di jalan Allah, tidak patah semangat dan tidak (pula) menyerah (kepada musuh). Dan Allah mencintai orang-orang yang sabar.';
const _nahl42 =
    '(yaitu) orang yang sabar dan hanya kepada Tuhan mereka bertawakal.';

void _check(String source, bool cutStart, bool cutEnd) {
  final s = buildSnippet(source, ['sabar']);
  expect(source.contains(s.text), isTrue);
  expect(s.text.length <= 100, isTrue);
  expect(s.cutStart, cutStart);
  expect(s.cutEnd, cutEnd);
  final expected = RegExp(
    'sabar',
    caseSensitive: false,
  ).allMatches(s.text).map((m) => [m.start, m.end]).toList();
  expect(s.highlights.map((r) => [r.start, r.end]).toList(), expected);
  expect(expected, isNotEmpty);
  // Whole words only: boundaries sit at text edges or after/before a space.
  expect(s.text.startsWith(' ') || s.text.endsWith(' '), isFalse);
  final at = source.indexOf(s.text);
  if (cutStart) expect(source[at - 1], ' ');
  if (cutEnd) expect(source[at + s.text.length], ' ');
}

void main() {
  test('Al-Baqarah 45', () => _check(_baqarah45, false, true));
  test('Al-Baqarah 153', () {
    _check(_baqarah153, true, true);
    // The second "sabar" (index 134) is outside the window.
    expect(buildSnippet(_baqarah153, ['sabar']).highlights.length, 1);
  });
  test("Ali 'Imran 146", () {
    _check(_ali146, true, false);
    expect(buildSnippet(_ali146, ['sabar']).text.endsWith('sabar.'), isTrue);
  });
  test('An-Nahl 42 shown whole', () {
    _check(_nahl42, false, false);
    expect(buildSnippet(_nahl42, ['sabar']).text, _nahl42);
  });

  test('capitalised match is highlighted', () {
    final s = buildSnippet('Sabar itu indah', ['sabar']);
    expect(s.highlights.single.start, 0);
    expect(s.highlights.single.end, 5);
  });

  test('no occurrence falls back to text start without highlights', () {
    final text = 'kata ' * 40;
    final s = buildSnippet(text.trimRight(), ['zzz']);
    expect(s.highlights, isEmpty);
    expect(s.cutStart, isFalse);
    expect(s.cutEnd, isTrue);
    expect(text.startsWith(s.text), isTrue);
  });

  test('very long text ending mid-word does not throw', () {
    final base = ('abcdefgh ' * 2000).substring(0, 16384);
    final mid = base.replaceRange(9000, 9005, 'sabar');
    final s1 = buildSnippet(mid, ['sabar']);
    expect(s1.highlights.length, 1);
    expect(s1.cutStart && s1.cutEnd, isTrue);

    final tail = '${base.substring(0, 16384 - 5)}sabar';
    final s2 = buildSnippet(tail, ['sabar']);
    expect(s2.cutEnd, isFalse);
    expect(s2.text.endsWith('sabar'), isTrue);

    final s3 = buildSnippet(base, ['nomatch']);
    expect(s3.cutEnd, isTrue);
  });

  test('no-match fallback without spaces is never empty', () {
    final text = 'x' * 150;
    final s = buildSnippet(text, ['zzz']);
    expect(s.text, 'x' * 100);
    expect(s.highlights, isEmpty);
    expect(s.cutStart, isFalse);
    expect(s.cutEnd, isTrue);

    final short = buildSnippet('x' * 60, ['zzz']);
    expect(short.text, 'x' * 60);
    expect(short.cutEnd, isFalse);
  });

  test('length-changing lowercase keeps highlight offsets on the original', () {
    const text = '\u0130\u0130\u0130 Sabar dan sabar';
    // The Dart VM lowercases length-preservingly, but JS (web) turns U+0130
    // into two code units; offsets must come from the original text.
    final s = buildSnippet(text, ['sabar']);
    expect(s.text, text);
    expect(s.highlights.map((r) => [r.start, r.end]).toList(), [
      [4, 9],
      [14, 19],
    ]);
  });
}
