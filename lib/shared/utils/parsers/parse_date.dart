import 'package:cloud_firestore/cloud_firestore.dart';

DateTime? parseDate(dynamic value) {
  if (value == null) return null;
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value);
  return null;
}

dynamic serializeDate(dynamic date, {bool forFirestore = true}) {
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
