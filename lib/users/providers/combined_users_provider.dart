// lib/users/providers/current_combined_user_provider.dart
import 'package:afyakit/users/extensions/auth_user_status_enum.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/models/user_profile_model.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/providers/auth_user_stream_provider.dart';
import 'package:afyakit/users/providers/user_profile_stream_provider.dart';

// somewhere central
final combinedUsersProvider = Provider.autoDispose<List<CombinedUser>>((ref) {
  final authAsync = ref.watch(authUserStreamProvider);
  final profAsync = ref.watch(userProfileStreamProvider);
  if (!authAsync.hasValue || !profAsync.hasValue) return const [];

  final authUsers = authAsync.value!;
  final profiles = profAsync.value!;
  final byUid = {for (final p in profiles) p.uid: p};

  return authUsers.map((auth) {
    final p = byUid[auth.uid] ?? UserProfile.blank(auth.uid);
    return CombinedUser(
      uid: auth.uid,
      email: auth.email,
      phoneNumber: auth.phoneNumber,
      status: AuthUserStatus.fromString(auth.status),
      tenantId: auth.tenantId,
      invitedOn: auth.invitedOn,
      activatedOn: auth.activatedOn,
      displayName: p.displayName,
      role: p.role,
      stores: p.stores,
      avatarUrl: p.avatarUrl,
      isSuperAdmin: auth.claims?['superadmin'] == true,
    );
  }).toList();
});
