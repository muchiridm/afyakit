import 'package:afyakit/features/auth_users/user_manager/extensions/user_status_x.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/controllers/user_manager_controller.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/features/auth_users/providers/auth_user_stream_provider.dart';
import 'package:afyakit/features/auth_users/utils/parse_user_role.dart';

import 'package:afyakit/features/auth_users/providers/current_user_session_providers.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';

import 'package:afyakit/features/auth_users/screens/invite_user_screen.dart';
import 'package:afyakit/features/auth_users/widgets/user_profile_card.dart';

import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final allAuthUsersProvider = FutureProvider.autoDispose<List<AuthUser>>((
  ref,
) async {
  final ctrl = ref.read(userManagerControllerProvider.notifier);
  return await ctrl.getAllUsers();
});

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
        if (currentUser == null || !currentUser.canManageUsers) {
          return const BaseScreen(
            body: Center(
              child: Text('🚫 You do not have access to this page.'),
            ),
          );
        }

        final allStoresAsync = ref.watch(
          inventoryLocationProvider(InventoryLocationType.store),
        );

        return allStoresAsync.when(
          loading: () => const BaseScreen(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) => BaseScreen(
            body: Center(child: Text('❌ Error loading store list: $err')),
          ),
          data: (allStores) => BaseScreen(
            maxContentWidth: 900,
            scrollable: true,
            header: _buildHeader(context),
            body: _buildUserList(ref, allStores),
          ),
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: ScreenHeader(
        'Manage User Profiles',
        trailing: Tooltip(
          message: 'Invite a new user to the system',
          child: ElevatedButton.icon(
            icon: const Icon(Icons.person_add),
            label: const Text('Invite User'),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const InviteUserScreen()),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildUserList(WidgetRef ref, List<InventoryLocation> allStores) {
    final usersAsync = ref.watch(authUserStreamProvider); // 👈 stream, not API

    return usersAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(child: Text('❌ Error loading users: $e')),
      data: (users) {
        if (users.isEmpty) {
          return const Center(child: Text('No users found.'));
        }
        return ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: users.length,
          separatorBuilder: (_, __) => const SizedBox(height: 12),
          itemBuilder: (_, i) => _buildUserCard(ref, users[i], allStores),
        );
      },
    );
  }

  Widget _buildUserCard(
    WidgetRef ref,
    AuthUser user,
    List<InventoryLocation> allStores,
  ) {
    final controller = ref.read(userManagerControllerProvider.notifier);

    final readableStores = user.stores.map((id) {
      final store = allStores.firstWhere(
        (s) => s.id == id,
        orElse: () => InventoryLocation(
          id: id,
          name: id,
          tenantId: '',
          type: InventoryLocationType.store,
        ),
      );
      return store.name;
    }).toList();

    return UserProfileCard(
      displayName: _displayLabelFor(user),
      email: user.email,
      phoneNumber: user.phoneNumber,
      role: user.effectiveRole.name, // via AuthUserX
      status: user.statusEnum.label, // via AuthUserStatusX
      storeLabels: readableStores,
      onAvatarTapped: () async {
        final newUrl = await DialogService.prompt(
          title: 'Update Avatar URL',
          initialValue: user.avatarUrl,
        );
        if (newUrl != null && newUrl.trim().isNotEmpty) {
          await controller.updateFields(user.uid, {'avatarUrl': newUrl.trim()});
        }
      },
      onRoleChanged: (newRole) async {
        if (newRole == null) return;

        switch (newRole) {
          case String s:
            await controller.updateUserRole(user.uid, role: parseUserRole(s));
        }
      },
      onEditStoresTapped: () async {
        final selected = await DialogService.editStoreList(
          allStores,
          user.stores,
        );
        if (selected != null) {
          await controller.setStores(user.uid, selected);
        }
      },
      onRemoveStore: (storeName) async {
        final match = allStores.firstWhereOrNull((s) => s.name == storeName);
        if (match != null) {
          final updated = [...user.stores]..remove(match.id);
          await controller.setStores(user.uid, updated);
        }
      },
      onDeleteUser: () {
        debugPrint('🔥 onDeleteUser triggered for: ${user.uid}');
        controller.deleteUser(user.uid);
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  String _displayLabelFor(AuthUser u) {
    final claimName = (u.claims?['displayName'] as String?)?.trim();
    if (claimName != null && claimName.isNotEmpty) return claimName;

    // If your AuthUser model now has displayName, prefer it:
    final modelName = (u as dynamic).displayName;
    if (modelName is String && modelName.trim().isNotEmpty) return modelName;

    if (u.email.trim().isNotEmpty) return u.email.trim();
    if (u.phoneNumber?.trim().isNotEmpty == true) return u.phoneNumber!.trim();
    return u.uid;
  }
}
