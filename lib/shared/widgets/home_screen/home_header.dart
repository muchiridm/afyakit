// lib/shared/screens/home_screen/home_header.dart

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/widgets/screen_header.dart';
import 'package:afyakit/core/records/deliveries/widgets/delivery_banner.dart';
import 'package:afyakit/core/auth_users/widgets/logout_button.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final displayName = ref.watch(tenantDisplayNameProvider);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          ScreenHeader(
            displayName,
            showBack: false,
            trailing: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [SizedBox(width: 8), LogoutButton()],
            ),
          ),
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: DeliveryBanner(), // visibility handled internally
          ),
        ],
      ),
    );
  }
}
