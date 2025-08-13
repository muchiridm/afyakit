/// Joins a list of parts into a single string, separated by a dot (·),
/// while skipping nulls and empty strings.
String joinNonEmpty(List<Object?> parts) {
  return parts
      .where((e) => e != null && e.toString().trim().isNotEmpty)
      .join(' · ');
}
