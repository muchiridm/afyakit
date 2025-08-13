import 'package:afyakit/users/models/auth_user_status_enum.dart';
import 'package:afyakit/users/models/user_profile.dart';
import 'package:afyakit/users/models/combined_user.dart';
import 'package:afyakit/shared/providers/users/auth_user_stream_provider.dart';
import 'package:afyakit/shared/providers/users/user_profile_stream_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Combines AuthUser and UserProfile into a unified object.
final combinedUserStreamProvider = StreamProvider<List<CombinedUser>>((ref) {
  final authUsersasync = ref.watch(authUserStreamProvider);
  final profilesAsync = ref.watch(userProfileStreamProvider);

  debugPrint(
    '🔄 Watching authUserStreamProvider: ${authUsersasync is AsyncData}',
  );
  debugPrint(
    '🔄 Watching userProfileStreamProvider: ${profilesAsync is AsyncData}',
  );

  return authUsersasync.when(
    data: (auth_users) {
      debugPrint('✅ Loaded ${auth_users.length} auth users');
      return profilesAsync.when(
        data: (profiles) {
          debugPrint('✅ Loaded ${profiles.length} profiles');
          final users = auth_users.map((auth) {
            final profile = profiles.firstWhere(
              (p) => p.uid == auth.uid,
              orElse: () => UserProfile.blank(auth.uid),
            );

            return CombinedUser(
              uid: auth.uid,
              email: auth.email,
              phoneNumber: auth.phoneNumber,
              status: AuthUserStatus.fromString(auth.status),
              tenantId: auth.tenantId,
              invitedOn: auth.invitedOn,
              activatedOn: auth.activatedOn,
              displayName: profile.displayName,
              role: profile.role,
              stores: profile.stores
                  .expand((s) => s.split(','))
                  .map((s) => s.trim())
                  .where((s) => s.isNotEmpty)
                  .toList(),
              avatarUrl: profile.avatarUrl,
            );
          }).toList();

          return Stream.value(users);
        },
        loading: () {
          debugPrint('⏳ Waiting for user profiles...');
          return const Stream.empty();
        },
        error: (err, stack) {
          debugPrint('❌ Error loading profiles: $err');
          return const Stream.empty();
        },
      );
    },
    loading: () {
      debugPrint('⏳ Waiting for auth users...');
      return const Stream.empty();
    },
    error: (err, stack) {
      debugPrint('❌ Error loading auth users: $err');
      return const Stream.empty();
    },
  );
});
