import 'package:afyakit/shared/utils/normalize/normalize_string.dart';
import 'package:flutter/material.dart';
import 'package:afyakit/features/inventory_view/widgets/inventory_item_tile_components/editable_chip_list.dart';

class UserProfileCard extends StatelessWidget {
  final String displayName;
  final String email;
  final String? phoneNumber;
  final String role;
  final String status;
  final List<String> storeLabels;

  final VoidCallback? onAvatarTapped;
  final ValueChanged<String?>? onRoleChanged;
  final VoidCallback? onEditStoresTapped;
  final ValueChanged<String>? onRemoveStore;
  final VoidCallback? onDeleteUser;

  const UserProfileCard({
    super.key,
    required this.displayName,
    required this.email,
    this.phoneNumber,
    required this.role,
    required this.status,
    required this.storeLabels,
    this.onAvatarTapped,
    this.onRoleChanged,
    this.onEditStoresTapped,
    this.onRemoveStore,
    this.onDeleteUser,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAvatar(),
            const SizedBox(width: 16),
            Expanded(child: _buildUserInfo()),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (onDeleteUser != null) _buildDeleteButton(),
                _buildRoleDropdown(),
                if (onEditStoresTapped != null) _buildEditStoresButton(),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return GestureDetector(
      onTap: onAvatarTapped,
      child: const Icon(Icons.person, size: 40, color: Colors.indigo),
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildLine(
          displayName.isNotEmpty ? displayName : 'Unnamed User',
          isBold: true,
          fontSize: 15,
        ),
        if (email.isNotEmpty) _buildLine(email),
        if (phoneNumber?.isNotEmpty ?? false) _buildLine(phoneNumber!),
        const SizedBox(height: 4),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            _infoLabel('Role', role.toPascalCase()),
            _infoLabel('Status', status.toPascalCase()),
          ],
        ),
        if (storeLabels.isNotEmpty) ...[
          const SizedBox(height: 10),
          EditableChipList(
            labelToId: {for (final label in storeLabels) label: label},
            onRemove: onRemoveStore,
          ),
        ],
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return DropdownButton<String>(
      value: role,
      onChanged: onRoleChanged,
      items: ['admin', 'manager', 'staff', 'viewOnly']
          .map((r) => DropdownMenuItem(value: r, child: Text(r.toPascalCase())))
          .toList(),
    );
  }

  Widget _buildEditStoresButton() {
    return TextButton.icon(
      icon: const Icon(Icons.store),
      label: const Text('Edit Stores'),
      onPressed: onEditStoresTapped,
    );
  }

  Widget _buildLine(String text, {bool isBold = false, double fontSize = 14}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text,
        style: TextStyle(
          fontSize: fontSize,
          fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  Widget _infoLabel(String label, String value) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          '$label: ',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    );
  }

  Widget _buildDeleteButton() {
    return IconButton(
      icon: const Icon(Icons.delete_forever, color: Colors.redAccent),
      tooltip: 'Delete User',
      onPressed: onDeleteUser,
    );
  }
}
