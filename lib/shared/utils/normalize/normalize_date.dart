import 'package:cloud_firestore/cloud_firestore.dart'; // 👈 For Timestamp

DateTime? normalizeDate(dynamic input) {
  if (input == null) return null;

  if (input is DateTime) return input;

  if (input is Timestamp) return input.toDate();

  if (input is int) return DateTime.fromMillisecondsSinceEpoch(input);

  if (input is String) {
    try {
      return DateTime.parse(input);
    } catch (_) {
      return null;
    }
  }

  return null;
}
