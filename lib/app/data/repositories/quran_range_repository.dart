import '../models/ayah.dart';

/// Reads a contiguous ayah range off the main isolate. Throws
/// ContentUnavailable for invalid refs, a closed worker or a worker failure.
abstract interface class QuranRangeRepository {
  /// Ayat from [start] to [end] inclusive, ordered, possibly across surahs.
  Future<List<Ayah>> getAyahRange(AyahRef start, AyahRef end);
  Future<void> close();
}
