import 'package:afyakit/features/hq/tenants/widgets/hp_tenants_tab.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'hq_controller.dart';
import '../../users/all_users/widgets/hq_all_users_tab.dart';
import '../../users/super_admins/hq_superadmins_tab.dart';

class HqShell extends ConsumerWidget {
  const HqShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(hqControllerProvider);

    // show ephemeral banners
    ref.listen(hqControllerProvider, (prev, next) {
      final banner = next.banner;
      if (banner != null && banner.isNotEmpty) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(banner)));
        ref.read(hqControllerProvider.notifier).clearBanner();
      }
    });

    final email = ref.watch(hqCurrentEmailProvider) ?? 'Account';

    // 3 pages – must stay in sync with destinations below
    final pages = const [
      HqTenantsTab(), // index 0 – Tenants (v2)
      HqAllUsersTab(), // index 1 – Users
      HqSuperadminsTab(), // index 2 – HQ Admins
    ];

    // clamp index so we never go out of range
    final safeIndex = state.tabIndex.clamp(0, pages.length - 1);

    return Stack(
      children: [
        Scaffold(
          appBar: AppBar(
            title: const Text('AfyaKit • HQ'),
            actions: [_AccountMenu(email: email)],
          ),
          body: pages[safeIndex],
          bottomNavigationBar: NavigationBar(
            selectedIndex: safeIndex,
            onDestinationSelected: (i) =>
                ref.read(hqControllerProvider.notifier).setTab(i),
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.business_center_outlined),
                label: 'Tenants',
              ),
              NavigationDestination(
                icon: Icon(Icons.people_alt),
                label: 'Users',
              ),
              NavigationDestination(
                icon: Icon(Icons.verified_user),
                label: 'HQ Admins',
              ),
            ],
          ),
        ),
        if (state.busy)
          AbsorbPointer(
            child: Container(
              color: Colors.black.withOpacity(0.08),
              alignment: Alignment.center,
              child: const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.4),
              ),
            ),
          ),
      ],
    );
  }
}

class _AccountMenu extends ConsumerWidget {
  const _AccountMenu({required this.email});
  final String email;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<HqAccountAction>(
      tooltip: 'Account',
      position: PopupMenuPosition.under,
      onSelected: (action) => ref
          .read(hqControllerProvider.notifier)
          .handleAccountAction(action, context: context),
      itemBuilder: (context) => [
        PopupMenuItem<HqAccountAction>(
          enabled: false,
          child: Text(
            email,
            style: Theme.of(context).textTheme.bodySmall,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const PopupMenuDivider(),
        const PopupMenuItem(
          value: HqAccountAction.refreshClaims,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.refresh),
            title: Text('Refresh claims'),
          ),
        ),
        const PopupMenuItem(
          value: HqAccountAction.signOut,
          child: ListTile(
            dense: true,
            leading: Icon(Icons.logout),
            title: Text('Sign out'),
          ),
        ),
      ],
      child: Padding(
        padding: const EdgeInsets.only(right: 8),
        child: Row(
          children: [
            const Icon(Icons.account_circle),
            const SizedBox(width: 6),
            Text(
              email.split('@').first,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(width: 6),
            const Icon(Icons.arrow_drop_down),
          ],
        ),
      ),
    );
  }
}
