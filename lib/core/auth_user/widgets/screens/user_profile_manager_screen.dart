import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';
import 'package:afyakit/core/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_user/extensions/user_type_x.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/auth_user/utils/user_format.dart';
import 'package:afyakit/core/auth_user/widgets/screens/user_profile_editor_screen.dart';
import 'package:afyakit/core/auth_user/widgets/user_profile_card.dart';
import 'package:afyakit/features/hq/users/tenant_users_provider.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';

import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfileManagerScreen extends ConsumerWidget {
  const UserProfileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      loading: () =>
          const BaseScreen(body: Center(child: CircularProgressIndicator())),
      error: (err, _) => BaseScreen(
        body: Center(child: Text('❌ Failed to load current user: $err')),
      ),
      data: (currentUser) {
        // Guard: only staff-like users with manage rights can see this page
        if (currentUser == null || !currentUser.canManageUsers) {
          return const BaseScreen(
            body: Center(
              child: Text('🚫 You do not have access to this page.'),
            ),
          );
        }

        final storesAsync = ref.watch(
          inventoryLocationProvider(InventoryLocationType.store),
        );
        final usersAsync = ref.watch(tenantUsersProvider);

        return BaseScreen(
          maxContentWidth: 900,
          scrollable: true,
          header: const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: ScreenHeader('Manage User Profiles'),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: storesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) =>
                  Center(child: Text('❌ Error loading store list: $e')),
              data: (allStores) {
                final storeNameById = _buildStoreNameMap(allStores);
                final theme = Theme.of(context);

                return usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) =>
                      Center(child: Text('❌ Error loading users: $e')),
                  data: (users) {
                    if (users.isEmpty) {
                      return const Center(
                        child: Text('No users found for this tenant.'),
                      );
                    }

                    // Optional: put current user first, then sort others by name
                    final sorted = [...users];
                    sorted.sort((a, b) {
                      if (a.uid == currentUser.uid) return -1;
                      if (b.uid == currentUser.uid) return 1;
                      return a.displayLabel().toLowerCase().compareTo(
                        b.displayLabel().toLowerCase(),
                      );
                    });

                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team members (${sorted.length})',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 12),
                        ...sorted.map((u) {
                          final storeLabels = u.stores
                              .map((id) => storeNameById[id] ?? id)
                              .toList();

                          final staffRoleLabels = u.staffRoles
                              .map((r) => r.label)
                              .toList();

                          return UserProfileCard(
                            displayName: u.displayLabel(),
                            email: u.email,
                            phoneNumber: u.phoneNumber,
                            userTypeLabel: u.type.label,
                            roleLabel: staffRoleLabel(u),
                            roleValue: null, // still read-only for now
                            statusLabel: u.status.label,
                            staffRoleLabels: staffRoleLabels,
                            storeLabels: storeLabels,
                            onAvatarTapped: () {
                              _openEditor(context, u);
                            },
                            onTap: () {
                              _openEditor(context, u);
                            },
                            onRoleChanged: null, // keep read-only
                            onEditStoresTapped: null,
                            onRemoveStore: null,
                            onDeleteUser: null,
                          );
                        }),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }

  Map<String, String> _buildStoreNameMap(List<InventoryLocation> locations) {
    return {for (final loc in locations) loc.id: loc.name};
  }

  void _openEditor(BuildContext context, dynamic user) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => UserProfileEditorScreen(user: user)),
    );
  }
}
