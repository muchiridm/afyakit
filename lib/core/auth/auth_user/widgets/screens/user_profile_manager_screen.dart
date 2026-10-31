import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/utils/resolve_user_display.dart';
import 'package:afyakit/core/auth/auth_user/utils/user_format.dart';
import 'package:afyakit/core/auth/auth_user/widgets/screens/user_profile_editor_screen.dart';
import 'package:afyakit/core/auth/auth_user/widgets/user_profile_card.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

import 'package:afyakit/features/hq/users/tenant_users_provider.dart';

import 'package:afyakit/features/inventory/locations/inventory_locations_providers.dart';

import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class UserProfileManagerScreen extends ConsumerWidget {
  const UserProfileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(currentUserProvider);

    return currentUserAsync.when(
      loading: () => const AppPage(
        maxWidth: 900,
        scrollable: false,
        header: AppHeader(title: 'Manage User Profiles'),
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (error, _) => AppPage(
        maxWidth: 900,
        scrollable: false,
        header: const AppHeader(title: 'Manage User Profiles'),
        body: Center(child: Text('Failed to load current user: $error')),
      ),
      data: (currentUser) {
        if (currentUser == null || !currentUser.canManageUsers) {
          return const AppPage(
            maxWidth: 900,
            scrollable: false,
            header: AppHeader(title: 'Manage User Profiles'),
            body: Center(child: Text('You do not have access to this page.')),
          );
        }

        final locationsAsync = ref.watch(inventoryLocationsProvider(null));

        final usersAsync = ref.watch(tenantUsersProvider);

        return AppPage(
          maxWidth: 900,
          scrollable: true,
          header: const AppHeader(title: 'Manage User Profiles'),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: locationsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (error, _) => Center(
                child: Text('Failed to load inventory locations: $error'),
              ),
              data: (locations) {
                final storeNameById = {
                  for (final location in locations) location.id: location.name,
                };

                return usersAsync.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (error, _) =>
                      Center(child: Text('Failed to load users: $error')),
                  data: (users) {
                    if (users.isEmpty) {
                      return const Center(
                        child: Text('No users found for this tenant.'),
                      );
                    }

                    final sorted = [...users]
                      ..sort((a, b) {
                        if (a.uid == currentUser.uid) return -1;
                        if (b.uid == currentUser.uid) return 1;

                        return a.displayLabel().toLowerCase().compareTo(
                          b.displayLabel().toLowerCase(),
                        );
                      });

                    final theme = Theme.of(context);

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
                        for (final user in sorted)
                          UserProfileCard(
                            user: user,
                            roleLabelOverride: staffRoleLabel(user),
                            roleValue: null,
                            storeLabels: user.stores
                                .map<String>(
                                  (storeId) =>
                                      storeNameById[storeId] ??
                                      storeId.toString(),
                                )
                                .toList(growable: false),
                            onAvatarTapped: () => _openEditor(context, user),
                            onTap: () => _openEditor(context, user),
                            onRoleChanged: null,
                            onEditStoresTapped: null,
                            onRemoveStore: null,
                            onDeleteUser: null,
                          ),
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

  void _openEditor(BuildContext context, AuthUser user) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileEditorScreen(user: user),
      ),
    );
  }
}
