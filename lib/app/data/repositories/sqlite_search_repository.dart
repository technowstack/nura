import 'package:sqlite3/sqlite3.dart';

import '../../core/errors.dart';
import '../../core/search_query.dart';
import '../../core/search_snippet.dart';
import '../models/hadith.dart';
import '../models/search_hit.dart';
import '../sources/content_database.dart';
import 'search_repository.dart';

/// Translation: one substring `LIKE` per word on the raw column (ANDed).
/// Arabic: FTS5 prefix `MATCH` on the normalized index. Only `?` parameters
/// carry user input; the SQL text depends on the word count alone.
class SqliteSearchRepository implements SearchRepository {
  SqliteSearchRepository(this._db);

  final ContentDatabase _db;

  ResultSet _select(String sql, List<Object?> args) {
    try {
      return _db.raw.select(sql, args);
    } on SqliteException catch (e) {
      throw ContentUnavailable('Konten tidak dapat dibaca: ${e.message}');
    } on StateError {
      // sqlite3 throws StateError (not SqliteException) on a closed database.
      throw const ContentUnavailable('Konten tidak dapat dibaca');
    }
  }

  @override
  Future<SearchPage> searchAyah(
    ParsedQuery q, {
    int afterRowId = 0,
    int limit = 30,
  }) async => _search(
    q,
    table: 'ayah',
    select: 't.surah_number, t.ayah_number, s.name_latin AS name',
    join: 'JOIN surah s ON s.number = t.surah_number',
    afterRowId: afterRowId,
    limit: limit,
    hit: (r, snippet) => AyahSearchHit(
      rowId: r['id'] as int,
      snippet: snippet,
      surahNumber: r['surah_number'] as int,
      ayahNumber: r['ayah_number'] as int,
      surahName: r['name'] as String,
    ),
  );

  @override
  Future<SearchPage> searchHadith(
    ParsedQuery q, {
    String? bookSlug,
    int afterRowId = 0,
    int limit = 30,
  }) async => _search(
    q,
    table: 'hadith',
    select: 't.book_slug, t.number, b.name',
    join: 'JOIN hadith_book b ON b.slug = t.book_slug',
    bookSlug: bookSlug,
    afterRowId: afterRowId,
    limit: limit,
    hit: (r, snippet) => HadithSearchHit(
      rowId: r['id'] as int,
      snippet: snippet,
      ref: HadithRef(r['book_slug'] as String, r['number'] as int),
      bookName: r['name'] as String,
    ),
  );

  SearchPage _search(
    ParsedQuery q, {
    required String table,
    required String select,
    required String join,
    required int afterRowId,
    required int limit,
    required SearchHit Function(Row r, Snippet snippet) hit,
    String? bookSlug,
  }) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    if (q.status != QueryStatus.ok) return SearchPage.empty;

    final String from;
    final String where;
    final List<Object?> args;
    if (q.isArabic) {
      from = '${table}_fts f JOIN $table t ON t.id = f.rowid';
      where = '${table}_fts MATCH ?';
      args = [q.match];
    } else {
      from = '$table t';
      where = List.filled(
        q.likePatterns.length,
        r"t.translation_id LIKE ? ESCAPE '\'",
      ).join(' AND ');
      args = [...q.likePatterns];
    }
    final book = bookSlug == null ? '' : ' AND t.book_slug = ?';
    // Arabic keys on the FTS rowid so the planner walks the index in order.
    final id = q.isArabic ? 'f.rowid' : 't.id';
    final rows = _select(
      'SELECT t.id, ${q.isArabic ? 't.arab' : 't.translation_id'} AS text, '
      '$select FROM $from $join WHERE $where$book AND $id > ? '
      'ORDER BY $id LIMIT ?',
      [...args, ?bookSlug, afterRowId, limit + 1],
    );
    return SearchPage(
      hits: [
        for (final r in rows.take(limit))
          hit(
            r,
            q.isArabic
                ? buildArabicSnippet(r['text'] as String, q.tokens)
                : buildSnippet(r['text'] as String, q.tokens),
          ),
      ],
      hasMore: rows.length > limit,
    );
  }
}
