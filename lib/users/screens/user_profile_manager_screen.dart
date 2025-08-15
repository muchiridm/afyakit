import 'package:afyakit/users/providers/auth_user_stream_provider.dart';
import 'package:afyakit/users/providers/user_profile_stream_provider.dart';
import 'package:collection/collection.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:afyakit/users/providers/combined_users_provider.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/users/controllers/profile_controller.dart';
import 'package:afyakit/users/models/combined_user_model.dart';
import 'package:afyakit/users/extensions/combined_user_x.dart';
import 'package:afyakit/users/screens/invite_user_screen.dart';
import 'package:afyakit/users/services/user_deletion_controller.dart';
import 'package:afyakit/users/widgets/user_profile_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfileManagerScreen extends ConsumerWidget {
  const UserProfileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUserAsync = ref.watch(combinedUserProvider);

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
    final authAsync = ref.watch(authUserStreamProvider);
    final profAsync = ref.watch(userProfileStreamProvider);
    final users = ref.watch(combinedUsersProvider);

    if (authAsync.isLoading || profAsync.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }
    final err = authAsync.error ?? profAsync.error;
    if (err != null) {
      return Center(child: Text('❌ Error loading users: $err'));
    }

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
  }

  Widget _buildUserCard(
    WidgetRef ref,
    CombinedUser user,
    List<InventoryLocation> allStores,
  ) {
    final editor = ref.read(profileControllerProvider(user.uid).notifier);

    final deletionController = ref.read(
      userDeletionControllerProvider.notifier,
    );

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
      displayName: user.displayName,
      email: user.email,
      phoneNumber: user.phoneNumber,
      role: user.role.name,
      status: user.status.name,
      storeLabels: readableStores,
      onAvatarTapped: () async {
        final newUrl = await DialogService.prompt(
          title: 'Update Avatar URL',
          initialValue: user.avatarUrl,
        );
        if (newUrl != null && newUrl.trim().isNotEmpty) {
          await editor.updateAvatar(user.uid, newUrl.trim());
        }
      },
      onRoleChanged: (newRole) {
        if (newRole != null) {
          editor.updateRole(user.uid, newRole);
        }
      },
      onEditStoresTapped: () async {
        final selected = await DialogService.editStoreList(
          allStores,
          user.stores,
        );
        if (selected != null) {
          editor.updateStores(user.uid, selected);
        }
      },
      onRemoveStore: (storeName) {
        final match = allStores.firstWhereOrNull((s) => s.name == storeName);
        if (match != null) {
          editor.removeStore(user.uid, user.stores, match.id);
        }
      },
      onDeleteUser: () {
        debugPrint('🔥 onDeleteUser triggered for: ${user.uid}');
        deletionController.deleteUser(user.uid, email: user.email);
      },
    );
  }
}
