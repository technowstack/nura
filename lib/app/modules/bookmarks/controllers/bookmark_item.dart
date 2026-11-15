import '../../../data/models/ayah.dart';
import '../../../data/models/hadith.dart';

/// Display model for one bookmark row: widgets only render [title] and [body].
sealed class BookmarkItem {
  const BookmarkItem({
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String title;
  final String body;
  final DateTime createdAt;
}

class AyahBookmarkItem extends BookmarkItem {
  const AyahBookmarkItem({
    required this.ref,
    required super.title,
    required super.body,
    required super.createdAt,
  });

  final AyahRef ref;
}

class HadithBookmarkItem extends BookmarkItem {
  const HadithBookmarkItem({
    required this.ref,
    required super.title,
    required super.body,
    required super.createdAt,
  });

  final HadithRef ref;
}
