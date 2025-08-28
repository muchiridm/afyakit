import 'package:afyakit/shared/utils/firestore_instance.dart';

class TenantUtil {
  static String? logo(dynamic v) {
    final s = (v as String?)?.trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static DateTime? parseTs(dynamic v) {
    if (v is Timestamp) return v.toDate();
    if (v is DateTime) return v;
    if (v is String && v.isNotEmpty) return DateTime.tryParse(v);
    if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
    return null;
  }
}
