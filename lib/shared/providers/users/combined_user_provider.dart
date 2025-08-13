import 'package:afyakit/users/models/auth_user_status_enum.dart';
import 'package:afyakit/users/models/user_role_enum.dart';
import 'package:afyakit/users/models/auth_user.dart';
import 'package:afyakit/users/models/combined_user.dart';
import 'package:afyakit/users/controllers/user_profile_controller.dart';
import 'package:afyakit/users/models/user_profile.dart';
import 'package:afyakit/shared/providers/tenant_id_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/controllers/user_session_controller.dart';

final combinedUserProvider = FutureProvider<CombinedUser?>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final authUserState = ref.watch(userSessionControllerProvider(tenantId));
  final authUser = authUserState.asData?.value;

  if (authUser == null) {
    debugPrint('👻 No AuthUser found — returning null');
    return null;
  }

  debugPrint('✅ AuthUser found: ${authUser.email} / UID: ${authUser.uid}');
  final controller = await ref.watch(
    userProfileControllerProvider(tenantId).future,
  );

  try {
    debugPrint('📡 Attempting to load UserProfile for UID: ${authUser.uid}');
    final profile = await controller.getProfile(authUser.uid);

    if (profile == null) {
      debugPrint(
        '⚠️ No UserProfile found for UID: ${authUser.uid} — using fallback',
      );
    } else {
      debugPrint(
        '✅ UserProfile loaded: ${profile.displayName} (${profile.role.name})',
      );
    }

    return _buildCombinedUser(authUser, profile);
  } catch (e, stack) {
    debugPrint('❌ Exception loading UserProfile for UID: ${authUser.uid}');
    debugPrint('🧵 $e');
    debugPrint(stack.toString());
    return _buildCombinedUser(authUser, null);
  }
});

CombinedUser _buildCombinedUser(AuthUser auth, UserProfile? profile) {
  return CombinedUser(
    uid: auth.uid,
    email: auth.email,
    phoneNumber: auth.phoneNumber,
    status: AuthUserStatus.fromString(auth.status),
    tenantId: auth.tenantId,
    invitedOn: auth.invitedOn,
    activatedOn: auth.activatedOn,
    displayName: profile?.displayName ?? '',
    role: profile?.role ?? UserRole.staff,
    stores: profile?.stores ?? [],
    avatarUrl: profile?.avatarUrl,
  );
}
