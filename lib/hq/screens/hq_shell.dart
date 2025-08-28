import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../controllers/hq_controller.dart';
import '../core/tenants/hq_tenants_tab.dart';
import '../core/all_users/widgets/hq_all_users_tab.dart';
import '../core/super_admins/hq_superadmins_tab.dart';

class HqShell extends ConsumerWidget {
  const HqShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hqControllerProvider);
    ref.listen(hqControllerProvider, (prev, next) {
      final banner = next.banner;
      if (banner != null && banner.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(banner)));
        ref.read(hqControllerProvider.notifier).clearBanner();
      }
    });

    final pages = const [HqTenantsTab(), HqAllUsersTab(), HqSuperadminsTab()];

    return Scaffold(
      appBar: AppBar(title: const Text('AfyaKit • HQ')),
      body: pages[state.tabIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: state.tabIndex,
        onDestinationSelected: (i) =>
            ref.read(hqControllerProvider.notifier).setTab(i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.business), label: 'Tenants'),
          NavigationDestination(icon: Icon(Icons.people_alt), label: 'Users'),
          NavigationDestination(
            icon: Icon(Icons.verified_user),
            label: 'HQ Admins',
          ),
        ],
      ),
    );
  }
}
