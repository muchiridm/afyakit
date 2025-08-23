import 'package:flutter/foundation.dart';

class ClaimValidator {
  /// Minimal requirement: we just need a tenant marker to consider the session usable.
  static bool isValid(Map<String, dynamic>? claims, {bool verbose = false}) {
    if (claims == null) {
      if (verbose) debugPrint('🔍 Claims are null');
      return false;
    }

    final tenant =
        claims['tenant'] ?? claims['tenantId'] ?? claims['tenant_id'];
    final ok = tenant is String && tenant.trim().isNotEmpty;

    if (verbose || !ok) {
      debugPrint('🧪 ClaimValidator.isValid=$ok → tenant=$tenant');
    }
    return ok;
  }

  /// DEPRECATED: Profile fields now live on the AuthUser model.
  /// Keep this returning TRUE when the session is valid so old guards don't block the UI.
  static bool hasProfileClaims(
    Map<String, dynamic>? claims, {
    bool verbose = false,
  }) {
    // Old check (kept only for logging)
    final role = (claims?['role'] as String?)?.trim();
    final stores = claims?['stores'];

    final oldComplete =
        (role != null && role.isNotEmpty) &&
        (stores is List && stores.isNotEmpty);

    if (verbose) {
      debugPrint(
        '🧪 ClaimValidator.hasProfileClaims (deprecated): oldComplete=$oldComplete '
        '→ role=$role, stores=$stores',
      );
    }

    // Don't gate the UI anymore; session validity is enough.
    return isValid(claims);
  }

  /// New: tells the app it should hydrate/merge from the model (auth_users)
  /// because profile bits are missing in claims.
  static bool shouldHydrateFromModel(Map<String, dynamic>? claims) {
    final role = (claims?['role'] as String?)?.trim();
    final stores = claims?['stores'];
    final hasRole = role != null && role.isNotEmpty;
    final hasStores = stores is List && stores.isNotEmpty;
    // hydrate if either is missing
    final hydrate = !(hasRole && hasStores);
    if (hydrate) {
      debugPrint('💧 ClaimValidator: hydrate from model (claims incomplete)');
    }
    return hydrate;
  }
}
