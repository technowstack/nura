class VerificationReport {
  VerificationReport();

  final List<String> errors = [];
  final List<String> warnings = [];

  bool get ok => errors.isEmpty;
}
