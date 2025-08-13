//lib/shared/utils/normalize/normalize_string.dart

extension NormalizeString on String {
  /// Returns the string with the first letter capitalized.
  ///
  /// `'hello' → 'Hello'`
  String capitalize() {
    final trimmed = trim();
    return trimmed.isEmpty
        ? this
        : '${trimmed[0].toUpperCase()}${trimmed.substring(1)}';
  }

  /// Returns the lowercase, trimmed version of the string.
  ///
  /// `' Equipment ' → 'equipment'`
  String normalize() => trim().toLowerCase();

  /// Compares this string to [other], ignoring case and whitespace.
  ///
  /// `' Equipment ' == 'equipment' → true`
  bool normalizedEquals(String other) => normalize() == other.normalize();

  /// Converts the string to PascalCase.
  ///
  /// `'equipment stock' → 'Equipment Stock'`
  String toPascalCase() => trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .map((word) => word.capitalize())
      .join(' ');
}
