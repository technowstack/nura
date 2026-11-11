/// Content could not be read (missing row or database failure).
class ContentUnavailable implements Exception {
  const ContentUnavailable(this.message);

  final String message;

  @override
  String toString() => 'ContentUnavailable: $message';
}
