import '../models/daily_content.dart';

/// Deterministic "1 Hari 1 Ayat/Hadis" selection from content.db.
abstract interface class DailyContentRepository {
  /// Null when the daily ayah list is empty.
  DailyContent? ayahFor(DateTime localDate);

  /// Null when the list is empty or its stored offsets are corrupt.
  DailyContent? hadithFor(DateTime localDate, HadithSource source);

  bool get hasAyah;
}
