// lib/core/auth/auth_user/widgets/user_badge.dart
// Presentation only: current session identity, app role and optional UX switch.
// Contact details are edited in Native Contacts via the self-profile route.

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/utils/resolve_user_display.dart';
import 'package:afyakit/core/auth/auth_user/widgets/user_profile_editor_screen.dart';
import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/capabilities/widgets/feature_gate.dart';
import 'package:afyakit/features/home/enums/entry_mode.dart';
import 'package:afyakit/features/home/providers/entry_mode_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class UserBadge extends ConsumerWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Text('Account unavailable'),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final name = user.displayLabel();
        final profileAction = () => _openProfile(context);

        if (!user.hasStaffWorkspace) {
          return _badge(
            context,
            name: name,
            role: 'Member',
            onProfile: profileAction,
          );
        }

        final staffRole = user.staffRoles.primaryRole?.label ?? 'Staff';
        final currentMode = ref.watch(staffViewModeProvider);

        return FeatureGate(
          // Keep existing retail-only switch behavior; app permissions do
          // not change when the staff member switches the home UX.
          featureKey: FeatureKeys.retail,
          fallback: _badge(
            context,
            name: name,
            role: staffRole,
            onProfile: profileAction,
          ),
          child: _badge(
            context,
            name: name,
            role: currentMode == EntryMode.member ? 'Member' : staffRole,
            onProfile: profileAction,
            onSwitch: () {
              ref
                  .read(staffViewModeProvider.notifier)
                  .state = currentMode == EntryMode.staff
                  ? EntryMode.member
                  : EntryMode.staff;
            },
          ),
        );
      },
    );
  }

  void _openProfile(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const UserProfileEditorScreen()),
    );
  }

  Widget _badge(
    BuildContext context, {
    required String name,
    required String role,
    required VoidCallback onProfile,
    VoidCallback? onSwitch,
  }) {
    final theme = Theme.of(context);
    final radius = BorderRadius.circular(12);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: radius,
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          InkWell(
            borderRadius: radius,
            onTap: onProfile,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person, size: 16, color: Colors.black54),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 140),
                    child: Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Container(
            height: 18,
            width: 1,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: Colors.grey.shade300,
          ),
          InkWell(
            borderRadius: radius,
            onTap: onSwitch,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.indigo.shade50,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      role,
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  if (onSwitch != null) ...[
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.swap_horiz,
                      size: 14,
                      color: Colors.black54,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
