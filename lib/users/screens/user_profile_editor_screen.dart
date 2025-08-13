import 'package:afyakit/dev/dev_role_switcher.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_controller.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/users/controllers/user_profile_editor_controller.dart';
import 'package:afyakit/users/models/combined_user_x.dart';
import 'package:afyakit/users/models/combined_user.dart';
import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:afyakit/shared/screens/base_screen.dart';
import 'package:afyakit/shared/screens/screen_header.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserProfileEditorScreen extends ConsumerWidget {
  final String tenantId;
  final Map<String, String>? inviteParams;
  final _formKey = GlobalKey<FormState>();

  UserProfileEditorScreen({
    super.key,
    required this.tenantId,
    this.inviteParams,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final inviteUid = inviteParams?['uid'];
    final controller = ref.watch(
      userProfileEditorControllerProvider(inviteUid).notifier,
    );
    final state = ref.watch(userProfileEditorControllerProvider(inviteUid));
    final user = controller.user;

    if (user == null) {
      return const BaseScreen(
        body: Center(child: Text('⚠️ No user profile found.')),
      );
    }

    return BaseScreen(
      maxContentWidth: 600,
      scrollable: true,
      header: const Padding(
        padding: EdgeInsets.symmetric(vertical: 16),
        child: ScreenHeader('My Profile'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _buildAvatar(user.displayName),
            const SizedBox(height: 24),
            _buildEditableFields(controller),
            const SizedBox(height: 32),
            _buildReadOnlyFields(ref, user),
            const SizedBox(height: 32),
            if (user.email == 'muchiridm@gmail.com')
              DevRoleSwitcher(user: user, tenantId: tenantId),
            const SizedBox(height: 24),
            _buildSaveButton(context, controller, state),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(String displayName) {
    final initials = _initials(displayName);
    return Column(
      children: [
        CircleAvatar(
          radius: 48,
          backgroundColor: Colors.indigo.shade100,
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: Colors.indigo,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          displayName.isNotEmpty ? displayName : 'Unnamed User',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }

  Widget _buildEditableFields(UserProfileEditorController controller) {
    return Form(
      key: _formKey,
      child: Column(
        children: [
          TextFormField(
            controller: controller.nameController,
            decoration: const InputDecoration(
              labelText: 'Display Name',
              hintText: 'e.g. Dr. John Doe',
            ),
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return 'Display name is required';
              }
              return null;
            },
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: controller.phoneController,
            decoration: const InputDecoration(labelText: 'WhatsApp Number'),
            keyboardType: TextInputType.phone,
            // Optional: validator
          ),
        ],
      ),
    );
  }

  Widget _buildReadOnlyFields(WidgetRef ref, CombinedUser user) {
    final storeLocationsAsync = ref.watch(
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
          storeLocationsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error loading stores: $e'),
            data: (locations) {
              final storeNames = locations
                  .where((loc) => user.stores.contains(loc.id))
                  .map((loc) => loc.name)
                  .toList();
              return TextFormField(
                initialValue: storeNames.isEmpty
                    ? 'No stores assigned'
                    : storeNames.join(', '),
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
          initialValue: user.status.name.capitalize(),
          readOnly: true,
          decoration: const InputDecoration(
            labelText: 'Account Status',
            filled: true,
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton(
    BuildContext context,
    UserProfileEditorController controller,
    AsyncValue<void> state,
  ) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        icon: state.isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: const Text('Save Changes'),
        onPressed: state.isLoading
            ? null
            : () async {
                if (!(_formKey.currentState?.validate() ?? false)) {
                  // 👀 Optional: focus first error field, or show a snackbar
                  return;
                }

                final success = await controller.submit(context);
                if (success && context.mounted) {
                  Navigator.pop(context);
                }
              },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(' ').where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts[0][0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }
}
