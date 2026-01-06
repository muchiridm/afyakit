// lib/shared/widgets/home_screens/member/member_home_header.dart

import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/shared/widgets/home_screens/common/catalog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth/widgets/logout_button.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';

class MemberHomeHeader extends ConsumerWidget {
  const MemberHomeHeader({super.key, required this.user, this.onSwitchToStaff});

  final AuthUser user;
  final VoidCallback? onSwitchToStaff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);
    final theme = Theme.of(context);

    final greetingName = user.displayName.isNotEmpty
        ? user.displayName
        : user.phoneNumber;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScreenHeader(
            tenantName,
            showBack: false,
            leading: const CatalogButton(), // ⭐ NEW ⭐
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSwitchToStaff != null)
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Member view'),
                    onPressed: onSwitchToStaff,
                  ),
                const SizedBox(width: 8),
                const LogoutButton(),
              ],
            ),
            wrapTrailing: true,
          ),

          const SizedBox(height: 12),
          Text(
            'Hi, $greetingName 👋',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),

          if ((user.accountNumber ?? '').isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              'Member ID: ${user.accountNumber}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.hintColor,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
