// lib/users/widgets/invited_users_list.dart
import 'package:afyakit/users/user_manager/controllers/user_manager_controller.dart';
import 'package:afyakit/users/user_manager/extensions/user_status_x.dart';
import 'package:afyakit/users/user_manager/models/auth_user_model.dart';
import 'package:afyakit/users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/users/utils/label_for_user_role.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:timeago/timeago.dart' as timeago;

/// Provider: fetch *invited* users only (single source of truth via AuthUserController)
final invitedUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final ctrl = ref.read(userManagerControllerProvider.notifier);
  final all = await ctrl.getAllUsers();
  final invited = all.where((u) => u.statusEnum == UserStatus.invited).toList()
    ..sort((a, b) => a.email.toLowerCase().compareTo(b.email.toLowerCase()));
  return invited;
});

class InvitedUsersList extends ConsumerWidget {
  const InvitedUsersList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invitedAsync = ref.watch(invitedUsersProvider);

    return invitedAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('⚠️ Error loading invites: $e')),
      data: (invited) {
        if (invited.isEmpty) {
          return const Center(child: Text('🎉 No pending invites'));
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: invited.length,
          separatorBuilder: (_, __) => const Divider(),
          itemBuilder: (_, i) => _InviteTile(
            user: invited[i],
            invalidate: () {
              ref.invalidate(invitedUsersProvider);
            },
          ),
        );
      },
    );
  }
}

class _InviteTile extends ConsumerWidget {
  final AuthUser user;
  final VoidCallback invalidate;

  const _InviteTile({required this.user, required this.invalidate});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final controller = ref.read(userManagerControllerProvider.notifier);
    final roleLabel = labelForUserRole(user.effectiveRole);
    final invitedAgo = _invitedAgo(user);

    return ListTile(
      title: Text(user.email),
      subtitle: Text('Role: $roleLabel • Invited $invitedAgo'),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: 'Resend Invite',
            icon: const Icon(Icons.send),
            onPressed: () async {
              try {
                await controller.resendInvite(email: user.email);
                SnackService.showInfo('📨 Invite resent to ${user.email}');
              } catch (e) {
                SnackService.showError('❌ Failed to resend invite: $e');
              }
            },
          ),
          IconButton(
            tooltip: 'Cancel Invite',
            icon: const Icon(Icons.cancel),
            onPressed: () => _cancelInvite(context, controller),
          ),
        ],
      ),
    );
  }

  Future<void> _cancelInvite(
    BuildContext context,
    UserManagerController controller,
  ) async {
    final confirmed = await DialogService.confirm(
      title: 'Cancel Invite',
      content: 'Are you sure you want to cancel the invite for ${user.email}?',
      confirmText: 'Yes, Cancel',
    );

    if (confirmed != true) return;

    try {
      await controller.deleteUser(user.uid);
      invalidate();
      SnackService.showInfo('🗑️ Invite cancelled for ${user.email}');
    } catch (e) {
      SnackService.showError('❌ Failed to cancel invite: $e');
    }
  }

  String _invitedAgo(AuthUser u) {
    // Try to infer an invite timestamp from claims (common in custom flows)
    final claims = u.claims;
    DateTime? dt;

    final raw = claims?['invitedAt'];
    if (raw is int) {
      // milliseconds since epoch
      dt = DateTime.fromMillisecondsSinceEpoch(raw);
    } else if (raw is String) {
      dt = DateTime.tryParse(raw);
    }

    return dt != null ? timeago.format(dt) : 'recently';
  }
}
