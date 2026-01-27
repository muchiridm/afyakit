// lib/shared/utils/utils.dart

typedef JsonMap = Map<String, dynamic>;
typedef JsonObj = Map<String, Object?>;

bool isRecord(Object? v) => v is Map;

JsonObj? asObj(Object? v) => v is Map ? v.cast<String, Object?>() : null;

List<Object?>? asList(Object? v) => v is List ? v.cast<Object?>() : null;

/// Always returns trimmed string (possibly empty).
String readString(Object? v) => (v ?? '').toString().trim();

/// Returns null if trimmed string is empty.
String? readStringOrNull(Object? v) {
  final s = readString(v);
  return s.isEmpty ? null : s;
}

bool? readBool(Object? v) => v is bool ? v : null;

/// Always returns a number (fallback 0).
num readNum(Object? v, {num fallback = 0}) {
  if (v is num) return v;
  final s = readString(v);
  return num.tryParse(s) ?? fallback;
}

/// ✅ NEW: returns null if missing/empty/unparsable
num? readNumOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v;

  final s = readString(v);
  if (s.isEmpty) return null;

  return num.tryParse(s);
}

double readDouble(Object? v, {double fallback = 0}) {
  if (v is num) return v.toDouble();
  final s = readString(v);
  return double.tryParse(s) ?? fallback;
}

/// ✅ Optional but handy (same pattern as readNumOrNull)
double? readDoubleOrNull(Object? v) {
  if (v == null) return null;
  if (v is num) return v.toDouble();

  final s = readString(v);
  if (s.isEmpty) return null;

  return double.tryParse(s);
}

DateTime? readDateTime(Object? v) {
  final s = readString(v);
  if (s.isEmpty) return null;
  return DateTime.tryParse(s);
}

/// Common “snake_or_camel” getter.
/// Example: readKey(j, 'contact_id', 'contactId')
T? readKey<T>(JsonObj j, String a, [String? b, String? c]) {
  final v = j[a] ?? (b != null ? j[b] : null) ?? (c != null ? j[c] : null);
  return v is T ? v : null;
}
