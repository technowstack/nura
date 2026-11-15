import '../../core/search_query.dart';
import '../models/search_hit.dart';

abstract interface class SearchRepository {
  /// Ayah hits with `id > afterRowId`, in `id` order. Throws [ArgumentError]
  /// when [limit] < 1 and `ContentUnavailable` on database failure.
  Future<SearchPage> searchAyah(
    ParsedQuery q, {
    int afterRowId = 0,
    int limit = 30,
  });

  /// Hadith hits with `id > afterRowId`, in `id` (reading) order, optionally
  /// limited to one book.
  Future<SearchPage> searchHadith(
    ParsedQuery q, {
    String? bookSlug,
    int afterRowId = 0,
    int limit = 30,
  });
}
