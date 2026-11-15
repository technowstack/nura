/// Failures of the equran.id prayer API client.
sealed class PrayerApiException implements Exception {
  const PrayerApiException();
}

/// The API does not know this province/city name.
class UnknownRegion extends PrayerApiException {
  const UnknownRegion();
}

/// The region exists but the API has no schedule for that month.
class NoDataForMonth extends PrayerApiException {
  const NoDataForMonth();
}

/// Transport failure: no connection, timeout or server error.
class Network extends PrayerApiException {
  const Network();
}

/// The response (or request) is not usable; [reason] says why.
class BadResponse extends PrayerApiException {
  const BadResponse(this.reason);

  final String reason;

  @override
  String toString() => 'BadResponse($reason)';
}
