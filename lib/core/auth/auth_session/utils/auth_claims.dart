// lib/core/auth_users/utils/auth_claims.dart
import 'package:firebase_auth/firebase_auth.dart' as fb;

class ClaimsUtils {
  /// Read decoded ID-token claims. `force=true` will refresh the token first.
  static Future<Map<String, dynamic>> read({bool force = false}) async {
    final u = fb.FirebaseAuth.instance.currentUser;
    if (u == null) return const {};
    final tr = await u.getIdTokenResult(force);
    return Map<String, dynamic>.from(tr.claims ?? const {});
  }
}

/// Map helpers for token claims.
extension TenantClaimX on Map<String, dynamic> {
  String? get tenantIdClaim => (this['tenantId'] ?? this['tenant'])?.toString();
}
