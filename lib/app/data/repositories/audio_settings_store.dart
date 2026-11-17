/// Local audio settings.
abstract interface class AudioSettingsStore {
  /// Selected qari id; unknown or missing stored id gives the default.
  String get qariId;

  /// Throws [ArgumentError] when [id] is not in the qari catalog.
  void setQariId(String id);
}
