import '../../core/search_snippet.dart';
import 'hadith.dart';

/// One search result. [rowId] is `ayah.id` / `hadith.id` (the keyset cursor).
sealed class SearchHit {
  const SearchHit({required this.rowId, required this.snippet});

  final int rowId;
  final Snippet snippet;
}

class AyahSearchHit extends SearchHit {
  const AyahSearchHit({
    required super.rowId,
    required super.snippet,
    required this.surahNumber,
    required this.ayahNumber,
    required this.surahName,
  });

  final int surahNumber;
  final int ayahNumber;

  /// `surah.name_latin`.
  final String surahName;
}

class HadithSearchHit extends SearchHit {
  const HadithSearchHit({
    required super.rowId,
    required super.snippet,
    required this.ref,
    required this.bookName,
  });

  final HadithRef ref;
  final String bookName;
}

class SearchPage {
  const SearchPage({required this.hits, required this.hasMore});

  static const empty = SearchPage(hits: [], hasMore: false);

  final List<SearchHit> hits;
  final bool hasMore;
}
