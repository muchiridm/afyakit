// lib/shared/utils/utils.dart

typedef JsonMap = Map<String, dynamic>;
typedef JsonObj = Map<String, Object?>;

bool isRecord(Object? v) => v is Map;

JsonObj? asObj(Object? v) => v is Map ? v.cast<String, Object?>() : null;

List<Object?>? asList(Object? v) => v is List ? v.cast<Object?>() : null;

/// Always returns trimmed string, possibly empty.
String readString(Object? v) => (v ?? '').toString().trim();

/// Returns null if trimmed string is empty.
String? readStringOrNull(Object? v) {
  final String s = readString(v);
  return s.isEmpty ? null : s;
}

/// Same as [readStringOrNull], but the name makes intent clearer in models.
String? cleanStringOrNull(Object? v) {
  final String? s = readStringOrNull(v)?.trim();
  return s == null || s.isEmpty ? null : s;
}

bool? readBool(Object? v) => v is bool ? v : null;

/// Always returns a number, fallback 0.
num readNum(Object? v, {num fallback = 0}) {
  if (v is num) return v;

  final String s = readString(v);
  return num.tryParse(s) ?? fallback;
}

/// Returns null if missing, empty, or unparsable.
num? readNumOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v;

  final String s = readString(v);
  if (s.isEmpty) return null;

  return num.tryParse(s);
}

double readDouble(Object? v, {double fallback = 0}) {
  if (v is num) return v.toDouble();

  final String s = readString(v);
  return double.tryParse(s) ?? fallback;
}

/// Returns null if missing, empty, or unparsable.
double? readDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();

  final String s = readString(v);
  if (s.isEmpty) return null;

  return double.tryParse(s);
}

DateTime? readDateTime(Object? v) {
  final String s = readString(v);
  if (s.isEmpty) return null;

  return DateTime.tryParse(s);
}

/// Common snake_or_camel getter.
///
/// Example:
/// ```dart
/// readKey(j, 'contact_id', 'contactId')
/// ```
T? readKey<T>(JsonObj j, String a, [String? b, String? c]) {
  final Object? v =
      j[a] ?? (b != null ? j[b] : null) ?? (c != null ? j[c] : null);
  return v is T ? v : null;
}

/// Removes null, empty strings, empty lists, and empty maps from JSON maps.
///
/// Usage:
/// ```dart
/// return <String, Object?>{
///   'name': name,
///   'notes': notes,
/// }..removeWhere(removeEmpty);
/// ```
bool removeEmpty(Object? _, Object? value) {
  if (value == null) return true;
  if (value is String && value.trim().isEmpty) return true;
  if (value is List && value.isEmpty) return true;
  if (value is Map && value.isEmpty) return true;

  return false;
}
