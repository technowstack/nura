import 'package:sqlite3/sqlite3.dart';

import '../../../content_pipeline/content_schema.dart';
import '../../core/errors.dart';
import '../models/hadith.dart';
import '../models/hadith_book.dart';
import '../sources/content_database.dart';
import 'hadith_repository.dart';

/// Empirical threshold from measuring the source JSON: 19 of 38,102 hadith are
/// cut at 16,384 UTF-8 bytes; the next-lower Arabic is 14,833 bytes and the
/// next-lower translation 16,092 bytes.
const int sourceTruncationBytes = kSourceTruncationBytes;

class SqliteHadithRepository implements HadithRepository {
  SqliteHadithRepository(this._db);

  final ContentDatabase _db;

  ResultSet _select(String sql, [List<Object?> args = const []]) {
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
  Future<List<HadithBook>> listBooks() async =>
      _select(
            'SELECT slug, name, hadith_count, sort_order FROM hadith_book '
            'ORDER BY sort_order',
          )
          .map(
            (r) => HadithBook(
              slug: r['slug'] as String,
              name: r['name'] as String,
              hadithCount: r['hadith_count'] as int,
              sortOrder: r['sort_order'] as int,
            ),
          )
          .toList();

  @override
  Future<HadithPage> listPage(
    String slug, {
    int afterNumber = 0,
    int limit = 30,
  }) async {
    if (limit < 1) throw ArgumentError.value(limit, 'limit');
    final book = _select('SELECT 1 FROM hadith_book WHERE slug = ?', [slug]);
    if (book.isEmpty) throw ContentUnavailable('Kitab $slug tidak ditemukan');
    final rows = _select(
      'SELECT number, substr(translation_id, 1, 1000) AS preview, '
      'translation_length FROM hadith '
      'WHERE book_slug = ? AND number > ? ORDER BY number LIMIT ?',
      [slug, afterNumber, limit + 1],
    );
    return HadithPage(
      items: rows
          .take(limit)
          .map(
            (r) => HadithSummary(
              ref: HadithRef(slug, r['number'] as int),
              preview: r['preview'] as String,
              length: r['translation_length'] as int,
            ),
          )
          .toList(),
      hasMore: rows.length > limit,
    );
  }

  @override
  Future<Hadith> getHadith(HadithRef ref) async {
    final rows = _select(
      'SELECT b.name, h.arab, h.translation_id, h.translation_length, '
      'length(CAST(h.arab AS BLOB)) >= ? AS arab_cut, '
      'length(CAST(h.translation_id AS BLOB)) >= ? AS tr_cut '
      'FROM hadith h JOIN hadith_book b ON b.slug = h.book_slug '
      'WHERE h.book_slug = ? AND h.number = ?',
      [sourceTruncationBytes, sourceTruncationBytes, ref.slug, ref.number],
    );
    if (rows.isEmpty) {
      throw ContentUnavailable(
        'Hadis ${ref.slug} ${ref.number} tidak ditemukan',
      );
    }
    final r = rows.first;
    return Hadith(
      ref: ref,
      bookName: r['name'] as String,
      arab: r['arab'] as String,
      translation: r['translation_id'] as String,
      translationLength: r['translation_length'] as int,
      arabTruncated: (r['arab_cut'] as int) == 1,
      translationTruncated: (r['tr_cut'] as int) == 1,
    );
  }

  @override
  Future<HadithRef?> neighbor(HadithRef ref, {required bool next}) async {
    final known = _select(
      'SELECT 1 FROM hadith WHERE book_slug = ? AND number = ?',
      [ref.slug, ref.number],
    );
    if (known.isEmpty) {
      throw ContentUnavailable(
        'Hadis ${ref.slug} ${ref.number} tidak ditemukan',
      );
    }
    final rows = _select(
      'SELECT number FROM hadith WHERE book_slug = ? AND number '
      '${next ? '>' : '<'} ? ORDER BY number ${next ? 'ASC' : 'DESC'} LIMIT 1',
      [ref.slug, ref.number],
    );
    return rows.isEmpty
        ? null
        : HadithRef(ref.slug, rows.first['number'] as int);
  }
}
