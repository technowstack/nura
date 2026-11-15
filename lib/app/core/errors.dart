/// Content could not be read (missing row or database failure).
class ContentUnavailable implements Exception {
  const ContentUnavailable(this.message);

  final String message;

  @override
  String toString() => 'ContentUnavailable: $message';
}

/// User data (bookmarks, last read, settings) could not be read or written.
class UserDataUnavailable implements Exception {
  const UserDataUnavailable(this.message);

  final String message;

  @override
  String toString() => 'UserDataUnavailable: $message';
}
