// lib/core/auth_users/screens/invite_user_screen.dart

import 'package:afyakit/core/auth_users/controllers/auth_user/auth_user_controller.dart';
import 'package:afyakit/core/auth_users/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_role_x.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/current_user_providers.dart';
import 'package:afyakit/core/auth_users/widgets/permission_guard.dart';
import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/core/auth_users/widgets/invited_users_list.dart';

import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InviteUserScreen extends ConsumerWidget {
  const InviteUserScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final meAsync = ref.watch(currentAuthUserProvider);

    return meAsync.when(
      loading: () =>
          const BaseScreen(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BaseScreen(
        body: Center(child: Text('❌ Failed to load current user: $e')),
      ),
      data: (me) {
        return PermissionGuard(
          user: me,
          allowed: (u) => u.canManageUsers,
          fallback: const BaseScreen(
            body: Center(
              child: Text('🚫 You do not have access to this page.'),
            ),
          ),
          child: _InviteBody(),
        );
      },
    );
  }
}

class _InviteBody extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );
    final formState = ref.watch(authUserControllerProvider);
    final controller = ref.read(authUserControllerProvider.notifier);

    return BaseScreen(
      maxContentWidth: 600,
      scrollable: true,
      header: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader('Invite User'),
      ),
      body: storesAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('❌ Failed to load stores: $e')),
        data: (stores) => Padding(
          padding: const EdgeInsets.all(16),
          child: _InviteUserForm(
            formState: formState,
            controller: controller,
            stores: stores,
          ),
        ),
      ),
    );
  }
}

class _InviteUserForm extends StatelessWidget {
  final AuthUserState formState;
  final AuthUserController controller;
  final List<InventoryLocation> stores;

  const _InviteUserForm({
    required this.formState,
    required this.controller,
    required this.stores,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Form(
          child: Column(
            children: [
              TextFormField(
                initialValue: formState.email,
                decoration: const InputDecoration(labelText: 'Email Address'),
                onChanged: controller.setEmail,
                validator: (val) => val == null || !val.contains('@')
                    ? 'Enter a valid email'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<UserRole>(
                // ⬇️ use `value` so it updates when state changes
                initialValue: formState.role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: UserRole.values
                    .map(
                      (role) => DropdownMenuItem<UserRole>(
                        value: role,
                        child: Text(role.label),
                      ),
                    )
                    .toList(),
                onChanged: (role) {
                  if (role != null) controller.setFormRole(role);
                },
              ),
              const SizedBox(height: 16),
              _buildStoreSelector(),
              const SizedBox(height: 24),
              formState.isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton.icon(
                      icon: const Icon(Icons.send),
                      label: const Text('Send Invite'),
                      onPressed: () => controller.submit(context),
                    ),
            ],
          ),
        ),
        const SizedBox(height: 40),
        const Text(
          'Pending Invites',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        const SizedBox(height: 8),
        const InvitedUsersList(),
      ],
    );
  }

  Widget _buildStoreSelector() {
    if (stores.isEmpty) return const Text('No stores available to assign.');

    return InputDecorator(
      decoration: const InputDecoration(labelText: 'Stores (optional)'),
      child: Wrap(
        spacing: 8,
        children: stores.map((store) {
          final selected = formState.selectedStoreIds.contains(store.id);
          return FilterChip(
            label: Text(store.name),
            selected: selected,
            onSelected: (_) => controller.toggleStore(store.id),
          );
        }).toList(),
      ),
    );
  }
}
