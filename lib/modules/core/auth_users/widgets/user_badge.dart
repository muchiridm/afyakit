// lib/core/auth_users/widgets/user_badge.dart

import 'package:afyakit/modules/core/auth_users/extensions/user_type_x.dart';
import 'package:afyakit/modules/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/shared/providers/home_view_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/core/auth_users/widgets/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';
import 'package:afyakit/modules/core/auth_users/utils/user_format.dart'; // for staffRoleLabel

class UserBadge extends ConsumerWidget {
  const UserBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentUserProvider); // canonical current user
    final viewMode = ref.watch(homeViewModeProvider);

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

        final displayName = user.displayLabel(); // unified resolver
        final hasStaffWorkspace = user.type.hasStaffWorkspace;

        // Actual staff role label e.g. "Owner", "Pharmacist", "Doctor", "Staff"
        final actualStaffLabel = staffRoleLabel(user);

        // Chip label:
        // - pure member: always "Member"
        // - staff:
        //    - member mode → "Member"
        //    - staff mode  → actual staff role label
        final String roleLabel;
        if (!hasStaffWorkspace) {
          roleLabel = user.type.label; // "Member"
        } else {
          roleLabel = viewMode == HomeViewMode.member
              ? 'Member'
              : actualStaffLabel;
        }

        return _buildBadge(
          context,
          displayName: displayName,
          roleLabel: roleLabel,
          showSwitcher: hasStaffWorkspace,
          isStaffView: hasStaffWorkspace && viewMode == HomeViewMode.staff,
          onToggleView: hasStaffWorkspace
              ? () {
                  final current = ref.read(homeViewModeProvider);
                  final next = current == HomeViewMode.member
                      ? HomeViewMode.staff
                      : HomeViewMode.member;
                  ref.read(homeViewModeProvider.notifier).state = next;
                }
              : null,
          onTapProfile: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (_) => const UserProfileEditorScreen(),
              ),
            );
          },
        );
      },
    );
  }

  // ────────────────── helpers ──────────────────

  Widget _buildBadge(
    BuildContext context, {
    required String displayName,
    required String roleLabel,
    required bool showSwitcher,
    required bool isStaffView,
    required VoidCallback? onToggleView,
    required VoidCallback onTapProfile,
  }) {
    final theme = Theme.of(context);
    final switcherTooltip = isStaffView
        ? 'Switch to member'
        : 'Switch to staff';

    return InkWell(
      onTap: onTapProfile,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.person, size: 18, color: Colors.black54),
            const SizedBox(width: 6),
            Text(
              displayName,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(width: 8),
            _roleChip(theme, roleLabel),
            if (showSwitcher && onToggleView != null) ...[
              const SizedBox(width: 4),
              Tooltip(
                message: switcherTooltip,
                child: InkWell(
                  // local tap for switch – separate from profile tap
                  onTap: onToggleView,
                  borderRadius: BorderRadius.circular(16),
                  child: const Padding(
                    padding: EdgeInsets.all(2),
                    child: Icon(
                      Icons.swap_horiz,
                      size: 16,
                      color: Colors.black54,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
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
