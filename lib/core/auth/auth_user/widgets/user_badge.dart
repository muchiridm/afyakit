// lib/core/auth/auth_user/widgets/user_badge.dart

import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/providers/entry_mode_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/widgets/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

import 'package:afyakit/core/hq/tenants/models/feature_keys.dart';
import 'package:afyakit/core/hq/tenants/widgets/feature_gate.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/extensions/staff_role_x.dart';

class UserBadge extends ConsumerWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider);

    return meAsync.when(
      loading: () => const SizedBox(
        width: 18,
        height: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
      error: (_, __) => const Text(
        'Error',
        style: TextStyle(fontSize: 12, color: Colors.red),
      ),
      data: (user) {
        if (user == null) return const SizedBox.shrink();

        final displayName = user.displayLabel();

        // ✅ Use your canonical rule
        final hasStaffWorkspace = user.hasStaffWorkspace;

        final staffLabel = user.staffRoles.primaryRole?.label ?? 'Staff';

        if (!hasStaffWorkspace) {
          return _buildBadge(
            context,
            displayName: displayName,
            roleLabel: 'Member',
            showSwitcher: false,
            onToggleView: null,
            onTapProfile: () => _openProfile(context),
          );
        }

        final viewMode = ref.watch(staffViewModeProvider);

        final badgeWithSwitch = _buildBadge(
          context,
          displayName: displayName,
          roleLabel: viewMode == EntryMode.member ? 'Member' : staffLabel,
          showSwitcher: true,
          onToggleView: () => _toggleStaffViewMode(ref, viewMode),
          onTapProfile: () => _openProfile(context),
        );

        final badgeNoSwitch = _buildBadge(
          context,
          displayName: displayName,
          roleLabel: staffLabel,
          showSwitcher: false,
          onToggleView: null,
          onTapProfile: () => _openProfile(context),
        );

        return FeatureGate(
          featureKey: FeatureKeys.retail,
          fallback: badgeNoSwitch,
          child: badgeWithSwitch,
        );
      },
    );
  }

  void _toggleStaffViewMode(WidgetRef ref, EntryMode current) {
    final next = current == EntryMode.staff
        ? EntryMode.member
        : EntryMode.staff;
    ref.read(staffViewModeProvider.notifier).state = next;
  }

  void _openProfile(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const UserProfileEditorScreen()),
    );
  }

  Widget _buildBadge(
    BuildContext context, {
    required String displayName,
    required String roleLabel,
    required bool showSwitcher,
    required VoidCallback? onToggleView,
    required VoidCallback onTapProfile,
  }) {
    final theme = Theme.of(context);

    final Color bg = Colors.grey.shade100;
    final BorderRadius radius = BorderRadius.circular(12);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: radius,
        border: Border.all(color: Colors.grey.shade300),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          InkWell(
            onTap: onTapProfile,
            borderRadius: radius,
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
                      displayName,
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
            onTap: showSwitcher ? onToggleView : null,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _roleChip(theme, roleLabel),
                  if (showSwitcher) ...[
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

  Widget _roleChip(ThemeData theme, String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}
