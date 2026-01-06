class ValidationResult {
  final bool isValid;
  final String? errorMessage;

  const ValidationResult._(this.isValid, this.errorMessage);

  factory ValidationResult.valid() => const ValidationResult._(true, null);

  factory ValidationResult.invalid(String message) =>
      ValidationResult._(false, message);

  /// Returns a combined result from a list of [ValidationResult]s.
  /// If any are invalid, returns the first invalid message.
  static ValidationResult combine(List<ValidationResult> results) {
    for (final r in results) {
      if (!r.isValid) return r;
    }
    return ValidationResult.valid();
  }
}
