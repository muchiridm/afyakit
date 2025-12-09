// lib/shared/widgets/home_screens/staff/staff_home_header.dart

import 'package:afyakit/shared/widgets/home_screens/common/catalog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';
import 'package:afyakit/modules/inventory/records/deliveries/widgets/delivery_banner.dart';
import 'package:afyakit/modules/core/auth_users/widgets/logout_button.dart';

class StaffHomeHeader extends ConsumerWidget {
  const StaffHomeHeader({super.key, this.onSwitchToMember});

  final VoidCallback? onSwitchToMember;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(tenantDisplayNameProvider);
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          ScreenHeader(
            displayName,
            showBack: false,
            leading: const CatalogButton(), // ⭐ NEW ⭐
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onSwitchToMember != null)
                  TextButton.icon(
                    icon: const Icon(Icons.swap_horiz, size: 18),
                    label: const Text('Staff view'),
                    onPressed: onSwitchToMember,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      textStyle: theme.textTheme.bodySmall?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(width: 8),
                const LogoutButton(),
              ],
            ),
          ),

          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: DeliveryBanner(),
          ),
        ],
      ),
    );
  }
}
