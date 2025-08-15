import 'package:afyakit/users/providers/auth_user_stream_provider.dart';
import 'package:afyakit/users/providers/user_profile_stream_provider.dart';
import 'package:afyakit/users/services/user_deletion_controller.dart';
import 'package:afyakit/users/utils/label_for_user_role.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/extensions/auth_user_status_enum.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/users/providers/combined_users_provider.dart';
import 'package:afyakit/users/controllers/auth_user_controller.dart';

class InvitedUsersList extends ConsumerWidget {
  const InvitedUsersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(
      authUserStreamProvider,
    ); // AsyncValue<List<AuthUser>>
    final profAsync = ref.watch(
      userProfileStreamProvider,
    ); // AsyncValue<List<UserProfile>>
    final users = ref.watch(combinedUsersProvider); // List<CombinedUser>

    return _buildInvitesBody(context, authAsync, profAsync, users, ref);
  }

  // ────────────────────────────────────────────────────────────────────
  // UI builders
  // ────────────────────────────────────────────────────────────────────

  Widget _buildInvitesBody(
    BuildContext context,
    AsyncValue<List<dynamic>> authAsync,
    AsyncValue<List<dynamic>> profAsync,
    List<CombinedUser> users,
    WidgetRef ref,
  ) {
    final loadingOrError = _buildLoadingOrError(authAsync, profAsync);
    if (loadingOrError != null) return loadingOrError;

    final invited = _filterInvited(users);
    if (invited.isEmpty) {
      return const Center(child: Text('🎉 No pending invites'));
    }

    return _buildInvitesList(invited, ref, context);
  }

  Widget? _buildLoadingOrError(
    AsyncValue<List<dynamic>> authAsync,
    AsyncValue<List<dynamic>> profAsync,
  ) {
    if (authAsync.isLoading || profAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = authAsync.error ?? profAsync.error;
    if (err != null) {
      return Center(child: Text('⚠️ Error loading invites: $err'));
    }
    return null; // no loading/error → continue
  }

  List<CombinedUser> _filterInvited(List<CombinedUser> users) {
    return users.where((u) => u.status == AuthUserStatus.invited).toList()
      ..sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
  }

  Widget _buildInvitesList(
    List<CombinedUser> invited,
    WidgetRef ref,
    BuildContext context,
  ) {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: invited.length,
      separatorBuilder: (_, __) => const Divider(),
      itemBuilder: (_, i) => _buildInviteTile(context, ref, invited[i]),
    );
  }

  Widget _buildInviteTile(
    BuildContext context,
    WidgetRef ref,
    CombinedUser user,
  ) {
    final timeAgo = timeago.format(user.invitedOn ?? DateTime.now());
    final controller = ref.read(authUserControllerProvider.notifier);

    return ListTile(
      title: Text(user.email),
      subtitle: Text('Role: ${labelForUserRole(user.role)} • Invited $timeAgo'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Resend Invite',
            icon: const Icon(Icons.send),
            onPressed: () => _resendInvite(controller, user),
          ),
          IconButton(
            tooltip: 'Cancel Invite',
            icon: const Icon(Icons.cancel),
            onPressed: () => _cancelInvite(context, ref, user),
          ),
        ],
      ),
    );
  }

  Future<void> _resendInvite(
    AuthUserController controller,
    CombinedUser user,
  ) async {
    try {
      await controller.resendInvite(email: user.email);

      SnackService.showInfo('📨 Invite resent to ${user.email}');
    } catch (e) {
      SnackService.showError('❌ Failed to resend invite: $e');
    }
  }

  Future<void> _cancelInvite(
    BuildContext context,
    WidgetRef ref,
    CombinedUser user,
  ) async {
    final confirmed = await DialogService.confirm(
      title: 'Cancel Invite',
      content: 'Are you sure you want to cancel the invite for ${user.email}?',
      confirmText: 'Yes, Cancel',
    );

    if (confirmed != true) return;

    final deletionController = ref.read(
      userDeletionControllerProvider.notifier,
    );
    await ref.read(userDeletionControllerProvider.future); // 💉 force init
    await deletionController.deleteUserSilent(user.uid);

    debugPrint('🧨 Attempting to cancel invite for ${user.uid}');

    try {
      await deletionController.deleteUserSilent(user.uid);
      debugPrint('✅ Invite cancelled for ${user.uid}');
      SnackService.showInfo('🗑️ Invite cancelled for ${user.email}');
    } catch (e, st) {
      debugPrint('❌ Failed to cancel invite: $e');
      debugPrintStack(stackTrace: st);
      SnackService.showError('❌ Failed to cancel invite: $e');
    }
  }
}
