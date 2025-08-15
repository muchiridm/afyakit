// lib/users/screens/user_profile_editor_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/dev/dev_role_switcher.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';

import 'package:afyakit/users/controllers/auth_user_controller.dart';
import 'package:afyakit/users/models/auth_user_model.dart';
import 'package:afyakit/users/extensions/auth_user_x.dart';
import 'package:afyakit/users/extensions/auth_user_status_x.dart';
import 'package:afyakit/users/providers/current_user_provider.dart';

import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:afyakit/shared/services/dialog_service.dart';

/// Fetch a single AuthUser via controller (doc id = uid)
final authUserByIdProvider = FutureProvider.family
    .autoDispose<AuthUser?, String>((ref, uid) async {
      final ctrl = ref.read(authUserControllerProvider.notifier);
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

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Prefer uid from params; otherwise fall back to current session user.
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

    return userAsync.when(
      loading: () =>
          const BaseScreen(body: Center(child: CircularProgressIndicator())),
      error: (e, _) => BaseScreen(
        body: Center(child: Text('⚠️ Failed to load profile: $e')),
      ),
      data: (user) {
        if (user == null) {
          return const BaseScreen(
            body: Center(child: Text('⚠️ No user profile found.')),
          );
        }

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
                _AvatarBlock(
                  displayName: _name.text.trim().isEmpty
                      ? _fallbackName(user)
                      : _name.text.trim(),
                  avatarUrl: user.avatarUrl,
                  onEditAvatar: () async {
                    final newUrl = await DialogService.prompt(
                      title: 'Update Avatar URL',
                      initialValue: user.avatarUrl ?? '',
                    );
                    if (newUrl == null || newUrl.trim().isEmpty) return;
                    await ref
                        .read(authUserControllerProvider.notifier)
                        .updateFields(effectiveUid, {
                          'avatarUrl': newUrl.trim(),
                        });
                    // refresh this user
                    ref.invalidate(authUserByIdProvider(effectiveUid));
                  },
                ),
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
  // Editable form
  // ────────────────────────────────────────────────────────────

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
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Display name is required';
              }
              return null;
            },
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

  // ────────────────────────────────────────────────────────────
  // Save
  // ────────────────────────────────────────────────────────────

  Widget _buildSaveButton(BuildContext context, String uid) {
    final isBusy = ref.watch(authUserControllerProvider).isLoading;
    final ctrl = ref.read(authUserControllerProvider.notifier);

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
                // Refresh this user record
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
}

// ──────────────────────────────────────────────────────────────
// Read-only fields block
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
}

// ──────────────────────────────────────────────────────────────
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
