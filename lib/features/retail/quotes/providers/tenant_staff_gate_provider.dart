import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final tenantStaffGateProvider = FutureProvider.autoDispose<bool>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  try {
    final token = await user.getIdTokenResult();
    final claims = token.claims;
    if (claims == null) return false;

    final tenantsRaw = claims['tenants'];
    if (tenantsRaw is! Map) return false;

    final entry = tenantsRaw[tenantId];
    if (entry is! Map) return false;

    final staff = entry['staff'];
    return staff == true;
  } catch (_) {
    // If token fetch fails, be safe: assume NOT staff.
    return false;
  }
});
