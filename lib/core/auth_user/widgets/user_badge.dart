import 'package:afyakit/core/tenancy/providers/tenant_feature_providers.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/shared/providers/home_view_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_user/widgets/screens/user_profile_editor_screen.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';
import 'package:afyakit/core/auth_user/utils/user_format.dart'; // staffRoleLabel

class UserBadge extends ConsumerStatefulWidget {
  const UserBadge({super.key});

  @override
  ConsumerState<UserBadge> createState() => _UserBadgeState();
}

class _UserBadgeState extends ConsumerState<UserBadge> {
  bool _hoverProfile = false;
  bool _hoverRole = false;

  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);
    final viewMode = ref.watch(homeViewModeProvider);

    // ✅ New simplified features system: module roots only.
    final retailEnabled = ref.watch(tenantRetailEnabledProvider);

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
        final hasStaffWorkspace = user.type.hasStaffWorkspace;
        final actualStaffLabel = staffRoleLabel(user);

        // Members shouldn't care about enabled modules; this switch is only
        // for staff users who also have retail enabled (so they can see retail/member view).
        final String roleLabel;
        if (!hasStaffWorkspace) {
          roleLabel = user.type.label; // e.g. "Member"
        } else if (!retailEnabled) {
          roleLabel = actualStaffLabel;
        } else {
          roleLabel = viewMode == HomeViewMode.member
              ? 'Member'
              : actualStaffLabel;
        }

        final bool allowSwitch = hasStaffWorkspace && retailEnabled;
        final bool isStaffView =
            hasStaffWorkspace &&
            retailEnabled &&
            viewMode == HomeViewMode.staff;

        return _buildBadge(
          context,
          displayName: displayName,
          roleLabel: roleLabel,
          showSwitcher: allowSwitch,
          isStaffView: isStaffView,
          onToggleView: allowSwitch
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

    final Color baseBg = Colors.grey.shade100;
    final Color hoverBg = Colors.grey.shade200;

    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // LEFT HALF: avatar + name → profile
            MouseRegion(
              cursor: SystemMouseCursors.click,
              onEnter: (_) => setState(() => _hoverProfile = true),
              onExit: (_) => setState(() => _hoverProfile = false),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                curve: Curves.easeOut,
                color: _hoverProfile ? hoverBg : baseBg,
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: InkWell(
                  onTap: onTapProfile,
                  borderRadius: BorderRadius.circular(999),
                  splashColor: Colors.black12,
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
                    ],
                  ),
                ),
              ),
            ),

            // RIGHT HALF: role (+ switch icon) → toggle view (only when enabled)
            if (showSwitcher && onToggleView != null)
              MouseRegion(
                cursor: SystemMouseCursors.click,
                onEnter: (_) => setState(() => _hoverRole = true),
                onExit: (_) => setState(() => _hoverRole = false),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  curve: Curves.easeOut,
                  color: _hoverRole ? hoverBg : baseBg,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  child: InkWell(
                    onTap: onToggleView,
                    borderRadius: BorderRadius.circular(999),
                    splashColor: Colors.black12,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _roleChip(theme, roleLabel),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.swap_horiz,
                          size: 16,
                          color: Colors.black54,
                        ),
                      ],
                    ),
                  ),
                ),
              )
            else
              // No switcher – still show a clean right half (non-clickable).
              Container(
                color: baseBg,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: _roleChip(theme, roleLabel),
              ),
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
