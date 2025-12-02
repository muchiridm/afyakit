// lib/core/auth_users/screens/user_profile_editor_screen.dart
import 'package:afyakit/core/auth_users/controllers/auth_user/profile_controller.dart';
import 'package:afyakit/core/auth_users/utils/user_format.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_user_display.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_users/models/auth_user_model.dart';
import 'package:afyakit/core/auth_users/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth_users/extensions/user_status_x.dart';

import 'package:afyakit/shared/widgets/base_screen.dart';
import 'package:afyakit/shared/widgets/screen_header.dart';

import 'package:afyakit/dev/dev_role_switcher.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';

class UserProfileEditorScreen extends ConsumerStatefulWidget {
  final String tenantId;
  final Map<String, String>? inviteParams;

  const UserProfileEditorScreen({
    super.key,
    required this.tenantId,
    this.inviteParams,
  });

  @override
  ConsumerState<UserProfileEditorScreen> createState() =>
      _UserProfileEditorScreenState();
}

class _UserProfileEditorScreenState
    extends ConsumerState<UserProfileEditorScreen> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final scope = ProfileScope(
      tenantId: widget.tenantId,
      inviteUid: widget.inviteParams?['uid']?.trim(),
    );

    // init controller once
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(profileControllerProvider(scope).notifier).init();
    });

    final state = ref.watch(profileControllerProvider(scope));
    final ctrl = ref.read(profileControllerProvider(scope).notifier);

    if (state.uid.isEmpty) {
      return const BaseScreen(
        body: Center(child: Text('⚠️ No user id provided.')),
      );
    }

    if (state.loading && state.user == null) {
      return const BaseScreen(body: Center(child: CircularProgressIndicator()));
    }

    if (state.user == null) {
      return BaseScreen(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('⚠️ No user found.'),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: ctrl.retrySync,
                icon: const Icon(Icons.sync),
                label: const Text('Retry (sync)'),
              ),
            ],
          ),
        ),
      );
    }

    final user = state.user!;

    return BaseScreen(
      maxContentWidth: 640,
      scrollable: true,
      header: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader('My Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildHeaderBlock(
              context,
              user,
              onEditAvatar: () {
                ctrl.changeAvatar(context);
              },
            ),
            const SizedBox(height: 24),
            _buildEditableFields(state),
            const SizedBox(height: 32),
            _ReadOnlyFields(user: user),
            const SizedBox(height: 32),
            if (user.email == 'muchiridm@gmail.com')
              DevRoleSwitcher(user: user, tenantId: widget.tenantId),
            const SizedBox(height: 24),
            _buildSaveButton(context, ctrl, state),
          ],
        ),
      ),
    );
  }

  // ── UI blocks ───────────────────────────────────────────────

  Widget _buildHeaderBlock(
    BuildContext context,
    AuthUser user, {
    required VoidCallback onEditAvatar,
  }) {
    final display = user.displayLabel();

    return Column(
      children: [
        _AvatarBlock(
          displayName: display,
          avatarUrl: user.avatarUrl,
          onEditAvatar: onEditAvatar,
        ),
        const SizedBox(height: 8),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _RoleChip(
              label: roleLabel(user.role),
            ), // ✅ pass the role, not the whole user
            const SizedBox(width: 8),
            _RoleChip(label: user.status.label), // optional but nice
          ],
        ),
      ],
    );
  }

  Widget _buildEditableFields(ProfileFormState state) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: state.nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. Dr. John Doe',
            ),
            textInputAction: TextInputAction.next,
            validator: (value) => (value == null || value.trim().isEmpty)
                ? 'Display name is required'
                : null,
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: state.phoneController,
            decoration: const InputDecoration(labelText: 'WhatsApp Number'),
            keyboardType: TextInputType.phone,
          ),
        ],
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
                if (mounted && Navigator.canPop(context)) {
                  Navigator.pop(context);
                }
              },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────
// Read-only fields block (unchanged except imports)
// ──────────────────────────────────────────────────────────────

class _ReadOnlyFields extends ConsumerWidget {
  const _ReadOnlyFields({required this.user});
  final AuthUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final storesAsync = ref.watch(
      inventoryLocationProvider(InventoryLocationType.store),
    );

    return Column(
      children: [
        TextFormField(
          initialValue: user.email,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Email Address',
            filled: true,
          ),
        ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: _roleStaticLabel(user),
          readOnly: true,
          decoration: const InputDecoration(labelText: 'Role', filled: true),
        ),
        const SizedBox(height: 16),
        if (user.isManager)
          storesAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading stores: $e'),
            data: (locations) {
              final names = locations
                  .where((loc) => user.stores.contains(loc.id))
                  .map((loc) => loc.name)
                  .toList();
              return TextFormField(
                initialValue: names.isEmpty
                    ? 'No stores assigned'
                    : names.join(', '),
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Assigned Stores',
                  filled: true,
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        TextFormField(
          initialValue: user.status.label,
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Account Status',
            filled: true,
          ),
        ),
      ],
    );
  }

  static String _roleStaticLabel(AuthUser u) {
    final raw = (u.role).toString().trim();
    if (raw.isEmpty) return '—';
    final cleaned = raw.contains('.') ? raw.split('.').last : raw;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
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
  const _AvatarBlock({
    required this.displayName,
    required this.avatarUrl,
    required this.onEditAvatar,
  });

  final String displayName;
  final String? avatarUrl;
  final VoidCallback onEditAvatar;

  @override
  Widget build(BuildContext context) {
    final initials = initialsFromName(displayName);

    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            CircleAvatar(
              radius: 48,
              backgroundColor: Colors.indigo.shade100,
              backgroundImage:
                  (avatarUrl != null && avatarUrl!.trim().isNotEmpty)
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
            Material(
              color: Colors.white,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Change Avatar',
                onPressed: onEditAvatar,
                icon: const Icon(Icons.edit, size: 18),
              ),
            ),
          ],
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
