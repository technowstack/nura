import '../../../data/models/ayah.dart';
import '../../../data/models/bookmark.dart';
import '../../../data/models/surah.dart';

class BookmarkItem {
  const BookmarkItem({
    required this.bookmark,
    required this.surah,
    required this.ayah,
  });

  final Bookmark bookmark;
  final Surah surah;
  final Ayah ayah;
}
