import 'package:flutter/foundation.dart';

class ClaimValidator {
  static bool isValid(Map<String, dynamic>? claims, {bool verbose = false}) {
    if (claims == null) {
      if (verbose) debugPrint('🔍 Claims are null');
      return false;
    }

    final tenant = claims['tenant'];

    final isValid = tenant is String && tenant.trim().isNotEmpty;

    if (verbose || !isValid) {
      debugPrint('🧪 ClaimValidator: isValid=$isValid → tenant=$tenant');
    }

    return isValid;
  }

  static bool hasProfileClaims(
    Map<String, dynamic>? claims, {
    bool verbose = false,
  }) {
    if (claims == null) return false;

    final role = claims['role'];
    final stores = claims['stores'];

    final isComplete =
        role is String && role.trim().isNotEmpty && stores is List;

    if (verbose || !isComplete) {
      debugPrint(
        '🧪 ClaimValidator.hasProfileClaims: complete=$isComplete → role=$role, stores=$stores',
      );
    }

    return isComplete;
  }
}
