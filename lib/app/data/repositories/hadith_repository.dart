import '../models/hadith.dart';
import '../models/hadith_book.dart';

abstract interface class HadithRepository {
  Future<List<HadithBook>> listBooks();

  /// A non-positive [limit] is a programming error: throws [ArgumentError],
  /// not ContentUnavailable.
  Future<HadithPage> listPage(
    String slug, {
    int afterNumber = 0,
    int limit = 30,
  });

  Future<Hadith> getHadith(HadithRef ref);

  /// Throws ContentUnavailable if [ref] does not exist; null only at a real
  /// end of the book.
  /// Adjacent hadith in the same book by number order, or null at the ends.
  Future<HadithRef?> neighbor(HadithRef ref, {required bool next});
}
