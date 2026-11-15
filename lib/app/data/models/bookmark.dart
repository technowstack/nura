import 'ayah.dart';
import 'hadith.dart';

class Bookmark {
  const Bookmark({required this.ref, required this.createdAt});

  final AyahRef ref;
  final DateTime createdAt;
}

class HadithBookmark {
  const HadithBookmark({required this.ref, required this.createdAt});

  final HadithRef ref;
  final DateTime createdAt;
}
