List<String>? parseToStringList(dynamic input) {
  if (input == null) return null;

  if (input is List) {
    return input.whereType<String>().toList();
  }

  if (input is String) {
    return input
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  return null;
}
