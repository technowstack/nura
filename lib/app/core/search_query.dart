import 'package:nura/content_pipeline/text_normalizer.dart';

enum QueryStatus { empty, tooShort, ok }

/// A user search input turned into safe, bounded query material.
class ParsedQuery {
  const ParsedQuery({
    required this.status,
    required this.isArabic,
    required this.tokens,
    required this.match,
    required this.likePatterns,
  });

  final QueryStatus status;
  final bool isArabic;
  final List<String> tokens;

  /// FTS5 MATCH string (Arabic mode only).
  final String match;

  /// LIKE patterns for use with `ESCAPE '\'` (translation mode only).
  final List<String> likePatterns;
}

const _maxChars = 100;
const _maxTokens = 8;

final _arabicLetter = RegExp(r'[؀-ۿ]');
final _notWord = RegExp(r'[^\p{L}\p{N}\s]', unicode: true);
final _letterOrDigit = RegExp(r'[\p{L}\p{N}]', unicode: true);
final _spaces = RegExp(r'\s+');
final _likeSpecial = RegExp(r'[\\%_]');

ParsedQuery _result(QueryStatus s, {bool arabic = false}) => ParsedQuery(
  status: s,
  isArabic: arabic,
  tokens: const [],
  match: '',
  likePatterns: const [],
);

ParsedQuery parseSearchQuery(String raw) {
  final cut = raw.length > _maxChars ? raw.substring(0, _maxChars) : raw;
  if (cut.trim().isEmpty) return _result(QueryStatus.empty);

  if (_arabicLetter.hasMatch(cut)) {
    final tokens = normalizeArabicForSearch(cut)
        .replaceAll(_notWord, '')
        .split(_spaces)
        .where(_arabicLetter.hasMatch)
        .take(_maxTokens)
        .toList();
    if (tokens.join().length < 2) {
      return _result(QueryStatus.tooShort, arabic: true);
    }
    return ParsedQuery(
      status: QueryStatus.ok,
      isArabic: true,
      tokens: tokens,
      match:
          'arab : (${tokens.map((t) => '"${t.replaceAll('"', '""')}"*').join(' ')})',
      likePatterns: const [],
    );
  }

  final tokens = cut
      .split(_spaces)
      .where(_letterOrDigit.hasMatch)
      .take(_maxTokens)
      .toList();
  if (tokens.join().replaceAll(_notWord, '').length < 2) {
    return _result(QueryStatus.tooShort);
  }
  return ParsedQuery(
    status: QueryStatus.ok,
    isArabic: false,
    tokens: tokens,
    match: '',
    likePatterns: [
      for (final t in tokens)
        '%${t.replaceAllMapped(_likeSpecial, (m) => '\\${m[0]}')}%',
    ],
  );
}
