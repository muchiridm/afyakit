class PayloadSanitizer {
  /// Removes all entries where the value is null
  static Map<String, dynamic> sanitize(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null) {
        cleaned[key] = value;
      }
    });
    return cleaned;
  }

  /// Optional: Remove empty strings too
  static Map<String, dynamic> sanitizeStrict(Map<String, dynamic> data) {
    final cleaned = <String, dynamic>{};
    data.forEach((key, value) {
      if (value != null && (value is! String || value.trim().isNotEmpty)) {
        cleaned[key] = value;
      }
    });
    return cleaned;
  }
}
