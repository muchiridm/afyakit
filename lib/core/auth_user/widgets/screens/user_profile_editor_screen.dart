import 'package:afyakit/core/auth_user/controllers/profile_controller.dart';
import 'package:afyakit/core/auth_user/utils/user_format.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/extensions/user_status_x.dart';
import 'package:afyakit/core/auth_user/extensions/staff_role_x.dart';

import 'package:afyakit/shared/widgets/screens/base_screen.dart';
import 'package:afyakit/shared/widgets/screens/screen_header.dart';

import 'package:afyakit/features/inventory/locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

class UserProfileEditorScreen extends ConsumerStatefulWidget {
  const UserProfileEditorScreen({super.key, this.user});

  /// If null → edit current logged-in user.
  /// If non-null → admin editing a specific user.
  final AuthUser? user;

  @override
  ConsumerState<UserProfileEditorScreen> createState() =>
      _UserProfileEditorScreenState();
}

class _UserProfileEditorScreenState
    extends ConsumerState<UserProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileControllerProvider(widget.user).notifier).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(profileControllerProvider(widget.user));
    final ctrl = ref.read(profileControllerProvider(widget.user).notifier);

    // Still loading and no user yet → spinner
    if (state.loading && state.user == null) {
      return const BaseScreen(body: Center(child: CircularProgressIndicator()));
    }

    // Finished loading but no user → error
    if (state.user == null) {
      return BaseScreen(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️ No user found.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () => ctrl.init(),
                icon: const Icon(Icons.sync),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final user = state.user!;
    final isAdminEditing = state.isAdminEditing;
    final title = isAdminEditing ? 'Edit User Profile' : 'My Profile';

    return BaseScreen(
      maxContentWidth: 720,
      scrollable: true,
      header: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader(title),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderBlock(context, user),
            const SizedBox(height: 24),
            _buildIdentitySection(user, state),
            const SizedBox(height: 24),
            _buildEditableSection(state),
            const SizedBox(height: 24),
            _RoleAndStoreSection(user: user, isAdminEditing: isAdminEditing),
            const SizedBox(height: 24),
            _buildSaveButton(context, ctrl, state),
          ],
        ),
      ),
    );
  }

  // ── UI blocks ───────────────────────────────────────────────

  Widget _buildHeaderBlock(BuildContext context, AuthUser user) {
    final display = user.displayLabel();
    final roleLabelText = staffRoleLabel(user);

    return Column(
      children: [
        _AvatarBlock(displayName: display, avatarUrl: user.avatarUrl),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleChip(label: roleLabelText),
            const SizedBox(width: 8),
            _RoleChip(label: user.status.label),
          ],
        ),
      ],
    );
  }

  /// Top card: show all identity data upfront.
  Widget _buildIdentitySection(AuthUser user, ProfileFormState state) {
    final safeEmail = (user.email != null && user.email!.trim().isNotEmpty)
        ? user.email
        : null;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextFormField(
              controller: state.phoneController,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'WhatsApp Number (identity)',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            if (safeEmail != null) ...[
              TextFormField(
                initialValue: safeEmail,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email (tenant-scoped)',
                  filled: true,
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextFormField(
              initialValue: user.tenantId,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'Tenant ID',
                filled: true,
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: user.uid,
              readOnly: true,
              decoration: const InputDecoration(
                labelText: 'User ID',
                filled: true,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Display name edit (for everyone).
  Widget _buildEditableSection(ProfileFormState state) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: TextFormField(
            controller: state.nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. Dr. John Doe',
            ),
            textInputAction: TextInputAction.done,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Display name is required'
                : null,
          ),
        ),
      ),
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    ProfileController ctrl,
    ProfileFormState state,
  ) {
    final isBusy = state.loading;
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: isBusy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: const Text('Save Changes'),
        onPressed: isBusy
            ? null
            : () async {
                if (!(_formKey.currentState?.validate() ?? false)) return;
                await ctrl.save(context);
              },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Roles / stores / status section
// ──────────────────────────────────────────────────────────────

class _RoleAndStoreSection extends ConsumerWidget {
  const _RoleAndStoreSection({
    required this.user,
    required this.isAdminEditing,
  });

  final AuthUser user;
  final bool isAdminEditing;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(profileControllerProvider(user));
    final ctrl = ref.read(profileControllerProvider(user).notifier);

    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );

    final effectiveStatus = state.statusOverride ?? user.status;
    final effectiveRoles = state.staffRoleOverrides ?? user.staffRoles;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Status
            Text(
              'Account Status',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (isAdminEditing)
              DropdownButtonFormField<UserStatus>(
                initialValue: effectiveStatus,
                onChanged: (val) {
                  if (val != null) ctrl.setStatus(val);
                },
                items: UserStatus.values
                    .map(
                      (s) => DropdownMenuItem(value: s, child: Text(s.label)),
                    )
                    .toList(),
              )
            else
              TextFormField(
                initialValue: effectiveStatus.label,
                readOnly: true,
                decoration: const InputDecoration(filled: true),
              ),
            const SizedBox(height: 16),

            // Roles
            Text('Roles', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            if (isAdminEditing)
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: StaffRole.values.map((role) {
                  final selected = effectiveRoles.any(
                    (r) => r == role,
                  ); // simple contains
                  return FilterChip(
                    label: Text(role.label),
                    selected: selected,
                    onSelected: (_) => ctrl.toggleStaffRole(role),
                  );
                }).toList(),
              )
            else
              TextFormField(
                initialValue: effectiveRoles.isEmpty
                    ? 'Member'
                    : effectiveRoles.map((r) => r.label).join(', '),
                readOnly: true,
                decoration: const InputDecoration(filled: true),
              ),
            const SizedBox(height: 16),

            // Stores
            Text(
              'Assigned Stores',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            storesAsync.when(
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error loading stores: $e'),
              data: (locations) {
                final allStores = locations;
                final effectiveStoreIds = state.storeOverrides ?? user.stores;

                if (!isAdminEditing) {
                  final names = allStores
                      .where((loc) => effectiveStoreIds.contains(loc.id))
                      .map((loc) => loc.name)
                      .toList();
                  return TextFormField(
                    initialValue: names.isEmpty
                        ? 'No stores assigned'
                        : names.join(', '),
                    readOnly: true,
                    decoration: const InputDecoration(filled: true),
                  );
                }

                // Admin: multiselect chips for stores
                if (allStores.isEmpty) {
                  return const Text('No stores configured for this tenant.');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: allStores.map((store) {
                    final selected = effectiveStoreIds.contains(store.id);
                    return FilterChip(
                      label: Text(store.name),
                      selected: selected,
                      onSelected: (_) => ctrl.toggleStore(store.id),
                    );
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Small UI atoms
// ──────────────────────────────────────────────────────────────

class _RoleChip extends StatelessWidget {
  const _RoleChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.indigo.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: Colors.indigo.shade100),
      ),
      child: Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _AvatarBlock extends StatelessWidget {
  const _AvatarBlock({required this.displayName, required this.avatarUrl});

  final String displayName;
  final String? avatarUrl;

  @override
  Widget build(BuildContext context) {
    final initials = initialsFromName(displayName);

    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.indigo.shade100,
          backgroundImage: (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
              ? NetworkImage(avatarUrl!.trim())
              : null,
          child: (avatarUrl == null || avatarUrl!.trim().isEmpty)
              ? Text(
                  initials,
                  style: const TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.indigo,
                  ),
                )
              : null,
        ),
        const SizedBox(height: 12),
        Text(
          displayName.isNotEmpty ? displayName : 'Unnamed User',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}
