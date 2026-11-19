import '../../../content_pipeline/content_schema.dart';
import '../../core/daily_index.dart';
import '../models/ayah.dart';
import '../models/daily_content.dart';
import '../models/hadith.dart';
import '../sources/content_database.dart';
import 'daily_content_repository.dart';

class SqliteDailyContentRepository implements DailyContentRepository {
  SqliteDailyContentRepository(this._db);

  final ContentDatabase _db;

  int _count(String sql, [List<Object?> args = const []]) =>
      _db.raw.select(sql, args).single['c'] as int;

  /// Non-negative modulo, so dates before the epoch wrap too.
  int _seq(DateTime d, int n) => ((dayIndex(d) % n) + n) % n;

  @override
  bool get hasAyah => _count('SELECT COUNT(*) c FROM daily_ayah') > 0;

  @override
  DailyContent? ayahFor(DateTime localDate) {
    final n = _count('SELECT COUNT(*) c FROM daily_ayah');
    if (n == 0) return null;
    final rows = _db.raw.select(
      'SELECT a.surah_number, a.ayah_number, a.arab, a.translation_id, '
      's.name_latin, s.name_arab FROM daily_ayah d JOIN ayah a ON a.id = d.ayah_id '
      'JOIN surah s ON s.number = a.surah_number WHERE d.seq = ?',
      [_seq(localDate, n)],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final surah = r['surah_number'] as int;
    final ayah = r['ayah_number'] as int;
    return DailyContent(
      kind: DailyKind.ayah,
      arab: r['arab'] as String,
      translation: r['translation_id'] as String,
      reference: 'QS. ${r['name_latin']}: $ayah',
      deepLink: 'nura://ayah/$surah/$ayah',
      ayahRef: AyahRef(surah, ayah),
      surahNameArab: r['name_arab'] as String,
    );
  }

  @override
  DailyContent? hadithFor(DateTime localDate, HadithSource source) {
    final n = _count('SELECT COUNT(*) c FROM daily_hadith WHERE list = ?', [
      source.value,
    ]);
    if (n == 0) return null;
    final rows = _db.raw.select(
      'SELECT h.book_slug, h.number, h.arab, h.translation_id, d.arab_start, '
      'd.arab_end, d.tr_start, d.tr_end FROM daily_hadith d '
      'JOIN hadith h ON h.id = d.hadith_id WHERE d.list = ? AND d.seq = ?',
      [source.value, _seq(localDate, n)],
    );
    if (rows.isEmpty) return null;
    final r = rows.single;
    final arab = _slice(r['arab'] as String, r['arab_start'], r['arab_end']);
    final tr = _slice(
      r['translation_id'] as String,
      r['tr_start'],
      r['tr_end'],
    );
    if (arab == null || tr == null) return null;
    final slug = r['book_slug'] as String;
    final number = r['number'] as int;
    return DailyContent(
      kind: DailyKind.hadith,
      arab: arab,
      translation: tr,
      reference: 'HR. ${hadithBookNames[slug] ?? slug} No. $number',
      deepLink: 'nura://hadith/$slug/$number',
      hadithRef: HadithRef(slug, number),
    );
  }

  /// Dart substring (UTF-16 units) of the original column; null on corrupt
  /// offsets instead of throwing.
  static String? _slice(String s, Object? start, Object? end) {
    if (start is! int || end is! int) return null;
    if (start < 0 || end < start || end > s.length) return null;
    return s.substring(start, end);
  }
}
