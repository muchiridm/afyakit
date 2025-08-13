import 'package:flutter/foundation.dart';

class ClaimValidator {
  /// ✅ Returns `true` if the minimal valid claims exist
  static bool isValid(Map<String, dynamic>? claims, {bool verbose = false}) {
    if (claims == null) {
      if (verbose) debugPrint('🛑 ClaimValidator → claims is null');
      return false;
    }

    final tenant = claims['tenant'];
    final isValid = tenant is String && tenant.isNotEmpty;

    if (verbose || !isValid) {
      debugPrint(
        '🧪 ClaimValidator: isValid=$isValid → '
        'tenant=$tenant, role=${claims['role']}, stores=${claims['stores']}',
      );
    }

    return isValid;
  }

  /// 📦 Optional: returns the missing keys (useful in diagnostics/logging)
  static List<String> getMissingKeys(Map<String, dynamic>? claims) {
    if (claims == null) return ['tenant'];
    final missing = <String>[];

    if (claims['tenant'] == null || claims['tenant'].toString().isEmpty) {
      missing.add('tenant');
    }

    return missing;
  }
}
