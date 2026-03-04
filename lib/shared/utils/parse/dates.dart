// File: lib/shared/utils/parse/dates.dart
import 'package:cloud_firestore/cloud_firestore.dart';

/// Parses date-ish values into a DateTime.
///
/// Supported:
/// - Timestamp -> DateTime (local)
/// - DateTime  -> returned (normalized optional)
/// - String    -> DateTime.tryParse(...)
DateTime? parseDate(Object? value) {
  if (value == null) return null;
  if (value is DateTime) return value;
  if (value is Timestamp) return value.toDate();
  if (value is String) {
    final s = value.trim();
    if (s.isEmpty) return null;
    return DateTime.tryParse(s);
  }
  return null;
}

/// Normalize to date-only (00:00:00) in local time.
DateTime? normalizeDateOnly(DateTime? d) {
  if (d == null) return null;
  return DateTime(d.year, d.month, d.day);
}

/// Serialize a date for Firestore or API transport.
///
/// - If [forFirestore] true: returns Timestamp
/// - Else: returns ISO 8601 string (UTC)
///
/// Accepts DateTime or Timestamp (Timestamp is normalized to DateTime first).
dynamic serializeDate(Object? date, {bool forFirestore = true}) {
  if (date == null) return null;

  if (date is Timestamp) {
    date = date.toDate(); // normalize
  }

  if (date is! DateTime) {
    throw ArgumentError(
      'serializeDate() expected DateTime or Timestamp but got ${date.runtimeType}',
    );
  }

  return forFirestore
      ? Timestamp.fromDate(date)
      : date.toUtc().toIso8601String();
}

/// Format DateTime as `YYYY-MM-DD` (Zoho-friendly).
String formatYmd(DateTime d) {
  final dd = normalizeDateOnly(d)!;
  final y = dd.year.toString().padLeft(4, '0');
  final m = dd.month.toString().padLeft(2, '0');
  final day = dd.day.toString().padLeft(2, '0');
  return '$y-$m-$day';
}
