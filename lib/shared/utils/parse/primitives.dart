// File: lib/shared/utils/parse/primitives.dart
import 'dart:developer' as dev;

/// Optional hook for parse errors.
/// Use this if you want logging, otherwise leave null.
typedef ParseErrorHandler =
    void Function(
      Object error,
      StackTrace stack, {
      required Object? input,
      required String target,
    });

/// Default parse error logger (opt-in).
void logParseError(
  Object error,
  StackTrace stack, {
  required Object? input,
  required String target,
}) {
  dev.log(
    '❌ parse $target failed for input: $input',
    error: error,
    stackTrace: stack,
    name: 'parse',
  );
}

/// Trimmed string representation (never null).
String asTrimmedString(Object? v) => (v ?? '').toString().trim();

/// Trimmed string or null if empty.
String? asCleanStringOrNull(Object? v) {
  final s = asTrimmedString(v);
  return s.isEmpty ? null : s;
}

/// Parse int (nullable).
/// - accepts int, num (incl double), String ("12", "12.0"), and falls back to toString().
/// - "12.9" -> 12 (matches your current behavior).
int? asIntOrNull(Object? v, {ParseErrorHandler? onError}) {
  try {
    if (v == null) return null;

    if (v is int) return v;
    if (v is num) return v.toInt();

    final s = asTrimmedString(v);
    if (s.isEmpty) return null;

    // Allow "12.0" / "12.9"
    if (s.contains('.')) {
      final d = double.tryParse(s);
      return d?.toInt();
    }

    return int.tryParse(s);
  } catch (e, st) {
    onError?.call(e, st, input: v, target: 'int');
    return null;
  }
}

/// Parse int with fallback.
int asInt(Object? v, {int fallback = 0, ParseErrorHandler? onError}) =>
    asIntOrNull(v, onError: onError) ?? fallback;

/// Parse double (nullable).
double? asDoubleOrNull(Object? v, {ParseErrorHandler? onError}) {
  try {
    if (v == null) return null;

    if (v is double) return v;
    if (v is num) return v.toDouble();

    final s = asTrimmedString(v);
    if (s.isEmpty) return null;

    return double.tryParse(s);
  } catch (e, st) {
    onError?.call(e, st, input: v, target: 'double');
    return null;
  }
}

/// Parse double with fallback.
double asDouble(Object? v, {double fallback = 0, ParseErrorHandler? onError}) =>
    asDoubleOrNull(v, onError: onError) ?? fallback;

/// Parse num (nullable).
num? asNumOrNull(Object? v, {ParseErrorHandler? onError}) {
  try {
    if (v == null) return null;

    if (v is num) return v;

    final s = asTrimmedString(v);
    if (s.isEmpty) return null;

    return num.tryParse(s);
  } catch (e, st) {
    onError?.call(e, st, input: v, target: 'num');
    return null;
  }
}

/// Parse num with fallback.
num asNum(Object? v, {num fallback = 0, ParseErrorHandler? onError}) =>
    asNumOrNull(v, onError: onError) ?? fallback;

/// Parse bool (nullable).
/// Accepts bool, or strings like true/false/1/0/yes/no.
bool? asBoolOrNull(Object? v) {
  if (v == null) return null;
  if (v is bool) return v;

  final s = asTrimmedString(v).toLowerCase();
  if (s.isEmpty) return null;

  if (s == 'true' || s == '1' || s == 'yes') return true;
  if (s == 'false' || s == '0' || s == 'no') return false;

  return null;
}
