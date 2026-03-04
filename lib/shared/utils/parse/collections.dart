// File: lib/shared/utils/parse/collections.dart

/// Parses input into a List<String>.
///
/// Supported:
/// - List: keeps only String entries, trims, drops empties
/// - String: split by ',', trims, drops empties
///
/// If [dedupe] is true, removes duplicates (preserves order).
List<String>? parseToStringList(Object? input, {bool dedupe = false}) {
  if (input == null) return null;

  List<String> out;

  if (input is List) {
    out = input
        .whereType<String>()
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  } else if (input is String) {
    final s = input.trim();
    if (s.isEmpty) return const <String>[];

    out = s
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList(growable: false);
  } else {
    return null;
  }

  if (!dedupe || out.length < 2) return out;

  final seen = <String>{};
  final deduped = <String>[];
  for (final s in out) {
    if (seen.add(s)) deduped.add(s);
  }
  return deduped;
}
