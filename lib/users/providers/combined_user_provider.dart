// lib/users/providers/combined_user_provider.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/users/controllers/user_profile_controller.dart';
import 'package:afyakit/users/controllers/user_session_controller.dart';

import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/users/extensions/auth_user_status_enum.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/models/user_profile_model.dart';
import 'package:afyakit/users/utils/parse_user_role.dart';

final combinedUserProvider = FutureProvider<CombinedUser?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);

  // Read current auth user from session controller
  final authUser = ref
      .watch(userSessionControllerProvider(tenantId))
      .maybeWhen(data: (u) => u, orElse: () => null);

  if (authUser == null) {
    _log('👻 No AuthUser found — returning null');
    return null;
  }
  _log('✅ AuthUser: ${authUser.email} / ${authUser.uid}');

  // Get a profile controller for this tenant
  final profileController = await ref.watch(
    userProfileControllerProvider(tenantId).future,
  );

  // Try to load profile (don’t fail the whole build if it errors)
  UserProfile? profile;
  try {
    _log('📡 Loading UserProfile for ${authUser.uid}');
    profile = await profileController.getProfile(authUser.uid);
    if (profile == null) {
      _log('⚠️ No UserProfile for ${authUser.uid} — using fallback');
    } else {
      _log('✅ Profile: ${profile.displayName} (${profile.role.name})');
    }
  } catch (e, st) {
    _log('❌ Profile load failed: $e\n$st');
  }

  // Build the merged view regardless of profile outcome
  return _buildCombinedUser(authUser, profile);
});

CombinedUser _buildCombinedUser(AuthUser auth, UserProfile? profile) {
  // Role: claims-first → profile.role → 'staff'
  final claims = auth.claims;
  final claimRole = (claims?['role'] as String?)?.trim();
  final resolvedRole = parseUserRole(
    (claimRole != null && claimRole.isNotEmpty)
        ? claimRole
        : (profile?.role.name ?? 'staff'),
  );

  // Global / cross-tenant flag
  final isSuperAdmin = claims?['superadmin'] == true;

  // Normalize stores: split by ',', trim+lowercase, dedupe
  final stores = (profile?.stores ?? const <String>[])
      .expand((s) => s.split(','))
      .map((s) => s.normalize())
      .where((s) => s.isNotEmpty)
      .toSet()
      .toList();

  return CombinedUser(
    uid: auth.uid,
    email: auth.email,
    phoneNumber: auth.phoneNumber,
    status: AuthUserStatus.fromString(auth.status),
    tenantId: auth.tenantId,
    invitedOn: auth.invitedOn,
    activatedOn: auth.activatedOn,
    displayName: profile?.displayName ?? '',
    role: resolvedRole,
    stores: stores,
    avatarUrl: profile?.avatarUrl,
    isSuperAdmin: isSuperAdmin,
  );
}

void _log(String msg) {
  if (kDebugMode) debugPrint(msg);
}
