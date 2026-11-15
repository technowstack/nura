import '../models/hadith.dart';
import '../models/hadith_book.dart';

abstract interface class HadithRepository {
  Future<List<HadithBook>> listBooks();

  Future<HadithPage> listPage(
    String slug, {
    int afterNumber = 0,
    int limit = 30,
  });

  Future<Hadith> getHadith(HadithRef ref);

  /// Adjacent hadith in the same book by number order, or null at the ends.
  Future<HadithRef?> neighbor(HadithRef ref, {required bool next});
}
