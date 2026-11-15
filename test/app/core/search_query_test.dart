import 'package:flutter_test/flutter_test.dart';
import 'package:nura/app/core/search_query.dart';
import 'package:sqlite3/sqlite3.dart';

const _arabicHostile = [
  '"',
  '*',
  '-',
  'OR',
  'AND',
  'NEAR(',
  '(a)',
  'ال:ب',
  '^ك',
  'ك"ب',
];

void main() {
  test('empty and whitespace-only input -> empty', () {
    expect(parseSearchQuery('').status, QueryStatus.empty);
    expect(parseSearchQuery('   \n').status, QueryStatus.empty);
  });

  test('one letter -> tooShort', () {
    expect(parseSearchQuery('a').status, QueryStatus.tooShort);
    expect(parseSearchQuery('ك').status, QueryStatus.tooShort);
  });

  test('translation word keeps case and becomes a LIKE pattern', () {
    final q = parseSearchQuery('Sabar');
    expect(q.status, QueryStatus.ok);
    expect(q.isArabic, isFalse);
    expect(q.tokens, ['Sabar']);
    expect(q.likePatterns, ['%Sabar%']);
    expect(q.match, '');
  });

  test('punctuation stays in translation tokens', () {
    expect(parseSearchQuery('(kepada Allah').tokens, ['(kepada', 'Allah']);
  });

  test('likes are escaped', () {
    expect(parseSearchQuery('100%').likePatterns, [r'%100\%%']);
    expect(parseSearchQuery('a_b').likePatterns, [r'%a\_b%']);
    expect(parseSearchQuery(r'a\b').likePatterns, [r'%a\\b%']);
    expect(parseSearchQuery("'; DROP").likePatterns, ['%DROP%']);
  });

  test('words without letters or digits are dropped', () {
    final q = parseSearchQuery('- % sabar');
    expect(q.tokens, ['sabar']);
    expect(parseSearchQuery('- %').status, isNot(QueryStatus.ok));
  });

  test('arabic match only contains quoted prefix tokens', () {
    for (final raw in _arabicHostile) {
      final q = parseSearchQuery(raw);
      if (q.status != QueryStatus.ok || !q.isArabic) {
        expect(q.match, '');
        continue;
      }
      expect(
        q.match,
        matches(RegExp(r'^arab : \(("[^"]+"\*)( "[^"]+"\*)*\)$')),
      );
    }
    expect(parseSearchQuery('ال:ب').match, 'arab : ("الب"*)');
    expect(parseSearchQuery('ك"ب').match, 'arab : ("كب"*)');
  });

  test('punctuation-only input is not ok', () {
    expect(parseSearchQuery('"').status, isNot(QueryStatus.ok));
    expect(parseSearchQuery('()*-').status, isNot(QueryStatus.ok));
  });

  test('harakat-insensitive', () {
    final a = parseSearchQuery('الصَّلَاةَ');
    expect(a.isArabic, isTrue);
    expect(a.match, parseSearchQuery('الصلاه').match);
  });

  test('mixed input uses arabic mode and drops latin tokens', () {
    final q = parseSearchQuery('sabar الصلاة');
    expect(q.isArabic, isTrue);
    expect(q.tokens, ['الصلاه']);
    expect(q.likePatterns, isEmpty);
  });

  test('limits: 8 tokens, 100 chars', () {
    expect(parseSearchQuery('a1 b2 c3 d4 e5 f6 g7 h8 i9').tokens.length, 8);
    final q = parseSearchQuery('x' * 150);
    expect(q.tokens.single.length, 100);
  });

  test('arabic match strings run on FTS5 without error', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute(
      "CREATE VIRTUAL TABLE t USING fts5(arab, translation, content='', "
      "tokenize='unicode61')",
    );
    for (final raw in [..._arabicHostile, 'الصَّلَاةَ', 'sabar الصلاة']) {
      final q = parseSearchQuery(raw);
      if (q.match.isEmpty) continue;
      db.select('SELECT rowid FROM t WHERE t MATCH ?', [q.match]);
    }
  });

  test('translation LIKE patterns have no wildcard behavior', () {
    final db = sqlite3.openInMemory();
    addTearDown(db.dispose);
    db.execute('CREATE TABLE t(x TEXT)');
    for (final v in ['100%', 'a_b', 'abc']) {
      db.execute('INSERT INTO t VALUES (?)', [v]);
    }
    List<Object?> hit(String raw) => db
        .select(r"SELECT x FROM t WHERE x LIKE ? ESCAPE '\'", [
          parseSearchQuery(raw).likePatterns.single,
        ])
        .map((r) => r['x'])
        .toList();
    expect(hit('100%'), ['100%']);
    expect(hit('a_b'), ['a_b']);
  });

  test('Arabic punctuation alone keeps translation mode', () {
    final q = parseSearchQuery('sabar \u061F');
    expect(q.isArabic, isFalse);
    expect(q.status, QueryStatus.ok);
  });

  test('Arabic letters still switch to Arabic mode', () {
    expect(
      parseSearchQuery('\u0627\u0644\u0635\u0644\u0627\u0629').isArabic,
      isTrue,
    );
  });

  test('truncation never leaves a lone surrogate', () {
    final q = parseSearchQuery('${'a' * 99}\u{1F600}');
    expect(q.tokens.single.length, 99);
  });
}
