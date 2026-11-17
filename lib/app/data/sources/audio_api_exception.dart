/// Failures of the equran.id audio API client.
sealed class AudioApiException implements Exception {
  const AudioApiException();
}

/// Transport failure: no connection, timeout or server error.
class AudioNetwork extends AudioApiException {
  const AudioNetwork();
}

/// The response (or request) is not usable; [reason] says why.
class AudioBadResponse extends AudioApiException {
  const AudioBadResponse(this.reason);

  final String reason;

  @override
  String toString() => 'AudioBadResponse($reason)';
}

/// The API does not know this surah (HTTP 404).
class AudioNotFound extends AudioApiException {
  const AudioNotFound();
}
