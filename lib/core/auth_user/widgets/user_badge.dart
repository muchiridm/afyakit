import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/shared/home/models/home_mode.dart';
import 'package:afyakit/shared/home/providers/home_mode_provider.dart';
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
  @override
  Widget build(BuildContext context) {
    final meAsync = ref.watch(currentUserProvider);
    final mode = ref.watch(homeModeProvider);

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
        final allowSwitch = hasStaffWorkspace;

        // Canonical staff label (Owner/Admin/Manager/etc) with safe fallback
        final rawStaffLabel = staffRoleLabel(user).trim();
        final staffLabel = rawStaffLabel.isEmpty ? 'Staff' : rawStaffLabel;

        debugPrint(
          'UserBadge: mode=$mode allowSwitch=$allowSwitch '
          'user=${user.uid} type=${user.type} staffLabel="$staffLabel"',
        );

        final roleLabel = _roleLabel(
          user: user,
          hasStaffWorkspace: hasStaffWorkspace,
          allowSwitch: allowSwitch,
          mode: mode,
          staffLabel: staffLabel,
        );

        return _buildBadge(
          context,
          displayName: displayName,
          roleLabel: roleLabel,
          showSwitcher: allowSwitch,
          isStaffView: allowSwitch && mode == HomeMode.staff,
          onToggleView: allowSwitch ? () => _toggleMode(ref, mode) : null,
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

  // ────────────────── logic helpers ──────────────────

  String _roleLabel({
    required AuthUser user,
    required bool hasStaffWorkspace,
    required bool allowSwitch,
    required HomeMode mode,
    required String staffLabel,
  }) {
    // Member-only users: show their type label
    if (!hasStaffWorkspace) return user.type.label;

    // Staff users without toggle (shouldn't happen with current logic)
    if (!allowSwitch) return staffLabel;

    // Staff users with toggle: reflect current mode
    return mode == HomeMode.member ? 'Member' : staffLabel;
  }

  void _toggleMode(WidgetRef ref, HomeMode current) {
    final next = current == HomeMode.staff ? HomeMode.member : HomeMode.staff;

    debugPrint('UserBadge: toggleMode current=$current -> next=$next');

    ref.read(homeModeProvider.notifier).state = next;

    debugPrint('UserBadge: after write homeMode=${ref.read(homeModeProvider)}');
  }

  // ────────────────── UI helpers ──────────────────

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
