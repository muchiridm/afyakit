// lib/users/screens/user_profile_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/dev/dev_role_switcher.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';

import 'package:afyakit/features/auth_users/user_manager/controllers/user_manager_controller.dart';
import 'package:afyakit/features/auth_users/models/auth_user_model.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/auth_user_x.dart';
import 'package:afyakit/features/auth_users/user_manager/extensions/user_status_x.dart';
import 'package:afyakit/features/auth_users/user_operations/providers/current_user_providers.dart';
import 'package:afyakit/features/auth_users/user_operations/services/user_operations_service.dart';
import 'package:afyakit/features/auth_users/user_operations/services/user_operations_service.dart'
    show userOperationsServiceProvider;

import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

// Fetch a single AuthUser via controller (doc id = uid)
final authUserByIdProvider = FutureProvider.family
    .autoDispose<AuthUser?, String>((ref, uid) async {
      final ctrl = ref.read(userManagerControllerProvider.notifier);
      return ctrl.getUserById(uid);
    });

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
  final _name = TextEditingController();
  final _phone = TextEditingController();
  bool _seeded = false;
  bool _syncedOnce = false; // ensure we only auto-sync once

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final paramUid = widget.inviteParams?['uid']?.trim();
    final sessionAsync = ref.watch(currentUserProvider);

    final effectiveUid = (paramUid != null && paramUid.isNotEmpty)
        ? paramUid
        : sessionAsync.maybeWhen(
            data: (u) => (u?.uid ?? '').trim(),
            orElse: () => '',
          );

    if (effectiveUid.isEmpty) {
      return sessionAsync.when(
        loading: () =>
            const BaseScreen(body: Center(child: CircularProgressIndicator())),
        error: (e, _) => BaseScreen(
          body: Center(child: Text('⚠️ Failed to load session: $e')),
        ),
        data: (_) => const BaseScreen(
          body: Center(child: Text('⚠️ No user id provided.')),
        ),
      );
    }

    final userAsync = ref.watch(authUserByIdProvider(effectiveUid));

    // Auto-sync claims once if we landed here from an invite OR if the doc is missing.
    ref.listen<AsyncValue<AuthUser?>>(authUserByIdProvider(effectiveUid), (
      prev,
      next,
    ) async {
      if (_syncedOnce) return;
      final fromInvite = (widget.inviteParams ?? {}).isNotEmpty;
      final missing = next.hasValue && next.value == null;

      if (fromInvite || missing) {
        _syncedOnce = true;
        try {
          final svc = await ref.read(
            userOperationsServiceProvider(widget.tenantId).future,
          );
          await svc.syncClaimsAndRefresh();
          ref.invalidate(authUserByIdProvider(effectiveUid));
        } catch (_) {
          // best-effort
        }
      }
    });

    return userAsync.when(
      loading: () =>
          const BaseScreen(body: Center(child: CircularProgressIndicator())),
      error: (e, _) =>
          BaseScreen(body: Center(child: Text('⚠️ Failed to load user: $e'))),
      data: (user) {
        if (user == null) return _buildMissingUser(effectiveUid);

        // Seed form fields once.
        if (!_seeded) {
          _name.text = _displayLabelFor(user);
          _phone.text = user.phoneNumber ?? '';
          _seeded = true;
        }

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
                _buildHeaderBlock(user, effectiveUid),
                const SizedBox(height: 24),
                _buildEditableFields(),
                const SizedBox(height: 32),
                _ReadOnlyFields(user: user),
                const SizedBox(height: 32),
                if (user.email == 'muchiridm@gmail.com')
                  DevRoleSwitcher(user: user, tenantId: widget.tenantId),
                const SizedBox(height: 24),
                _buildSaveButton(context, effectiveUid),
              ],
            ),
          ),
        );
      },
    );
  }

  // ────────────────────────────────────────────────────────────
  // Private builders
  // ────────────────────────────────────────────────────────────

  Widget _buildMissingUser(String uid) {
    return BaseScreen(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('⚠️ No user found.'),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  final svc = await ref.read(
                    userOperationsServiceProvider(widget.tenantId).future,
                  );
                  await svc.syncClaimsAndRefresh();
                } finally {
                  ref.invalidate(authUserByIdProvider(uid));
                }
              },
              icon: const Icon(Icons.sync),
              label: const Text('Retry (sync)'),
            ),
          ],
        ),
      ),
    );
  }

  /// Header with avatar + role chip + (optional) quick edit for avatar.
  Widget _buildHeaderBlock(AuthUser user, String uid) {
    final display = _name.text.trim().isEmpty
        ? _fallbackName(user)
        : _name.text.trim();
    return Column(
      children: [
        _AvatarBlock(
          displayName: display,
          avatarUrl: user.avatarUrl,
          onEditAvatar: () async {
            final newUrl = await DialogService.prompt(
              title: 'Update Avatar URL',
              initialValue: user.avatarUrl ?? '',
            );
            if (newUrl == null || newUrl.trim().isEmpty) return;
            await ref.read(userManagerControllerProvider.notifier).updateFields(
              uid,
              {'avatarUrl': newUrl.trim()},
            );
            ref.invalidate(authUserByIdProvider(uid));
          },
        ),
        const SizedBox(height: 8),
        _RoleChip(label: _roleLabel(user)),
      ],
    );
  }

  Widget _buildEditableFields() {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: _name,
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
            controller: _phone,
            decoration: const InputDecoration(labelText: 'WhatsApp Number'),
            keyboardType: TextInputType.phone,
          ),
        ],
      ),
    );
  }

  Widget _buildSaveButton(BuildContext context, String uid) {
    final isBusy = ref.watch(userManagerControllerProvider).isLoading;
    final ctrl = ref.read(userManagerControllerProvider.notifier);

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
                final updates = <String, dynamic>{
                  'displayName': _name.text.trim(),
                  'phoneNumber': _phone.text.trim(),
                };
                await ctrl.updateFields(uid, updates);
                ref.invalidate(authUserByIdProvider(uid));
                if (context.mounted) Navigator.pop(context);
              },
      ),
    );
  }

  // ────────────────────────────────────────────────────────────
  // Helpers
  // ────────────────────────────────────────────────────────────

  String _fallbackName(AuthUser u) {
    if (u.displayName.trim().isNotEmpty) return u.displayName.trim();
    if (u.email.trim().isNotEmpty) return u.email.trim();
    if ((u.phoneNumber ?? '').trim().isNotEmpty) return u.phoneNumber!.trim();
    return u.uid;
  }

  String _displayLabelFor(AuthUser u) {
    if (u.displayName.trim().isNotEmpty) return u.displayName.trim();
    final claimName = (u.claims?['displayName'] as String?)?.trim();
    if (claimName != null && claimName.isNotEmpty) return claimName;
    return _fallbackName(u);
  }

  /// Produces a pretty label from raw role string: "admin" → "Admin"
  String _roleLabel(AuthUser u) {
    final raw = (u.role).toString().trim();
    if (raw.isEmpty) return '—';
    final cleaned = raw.contains('.') ? raw.split('.').last : raw;
    return cleaned[0].toUpperCase() + cleaned.substring(1);
  }
}

// ──────────────────────────────────────────────────────────────
// Read-only fields block (now includes Role)
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
          initialValue: user.statusEnum.label,
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

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final initials = _initials(displayName);

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
