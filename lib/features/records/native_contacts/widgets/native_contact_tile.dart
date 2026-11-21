import 'package:flutter/material.dart';

import '../native_contact.dart';

/// Responsive app-scoped Native Contact tile.
/// Shared lifecycle operations (archive, restore and purge) belong to HQ.
class NativeContactTile extends StatelessWidget {
  const NativeContactTile({
    super.key,
    required this.contact,
    required this.expanded,
    required this.onToggle,
    required this.onAddresses,
    required this.onProfiles,
    required this.onEdit,
    required this.onRemove,
    this.busy = false,
  });

  final NativeContact contact;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onAddresses;
  final VoidCallback onProfiles;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  bool get _active => contact.status.trim().toLowerCase() == 'active';

  String get _primaryPhone {
    for (final value in [
      contact.verifiedPhone,
      contact.mobile,
      contact.phone,
    ]) {
      if (value != null && value.trim().isNotEmpty) return value.trim();
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final secondaryLine = [
      if (contact.accountNumber.trim().isNotEmpty) contact.accountNumber.trim(),
      if (_primaryPhone.isNotEmpty) _primaryPhone,
    ].join(' · ');

    return LayoutBuilder(
      builder: (context, constraints) {
        final desktop = constraints.maxWidth >= 760;
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          clipBehavior: Clip.antiAlias,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              InkWell(
                onTap: onToggle,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        child: Icon(
                          contact.entityType == 'organization'
                              ? Icons.business_outlined
                              : Icons.person_outline,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              contact.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (secondaryLine.isNotEmpty) ...[
                              const SizedBox(height: 2),
                              Text(
                                secondaryLine,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                            if (!_active) ...[
                              const SizedBox(height: 2),
                              Text(
                                'Archived',
                                style: theme.textTheme.labelSmall?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      if (desktop) ...[
                        OutlinedButton.icon(
                          onPressed: busy || !_active ? null : onProfiles,
                          icon: const Icon(
                            Icons.medical_information_outlined,
                            size: 18,
                          ),
                          label: const Text('Profiles'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: busy || !_active ? null : onAddresses,
                          icon: const Icon(
                            Icons.location_on_outlined,
                            size: 18,
                          ),
                          label: const Text('Addresses'),
                        ),
                        const SizedBox(width: 8),
                        OutlinedButton.icon(
                          onPressed: busy || !_active ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                      ] else
                        _ContactActionsMenu(
                          busy: busy,
                          active: _active,
                          onAddresses: onAddresses,
                          onProfiles: onProfiles,
                          onEdit: onEdit,
                          onRemove: onRemove,
                        ),
                      const SizedBox(width: 4),
                      Icon(
                        expanded
                            ? Icons.keyboard_arrow_up
                            : Icons.keyboard_arrow_down,
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 220),
                curve: Curves.easeInOut,
                alignment: Alignment.topCenter,
                child: expanded
                    ? _ContactDetails(
                        contact: contact,
                        desktop: desktop,
                        busy: busy,
                        onRemove: onRemove,
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _ContactDetails extends StatelessWidget {
  const _ContactDetails({
    required this.contact,
    required this.desktop,
    required this.busy,
    required this.onRemove,
  });

  final NativeContact contact;
  final bool desktop;
  final bool busy;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final details = <String>[
      if (contact.verifiedPhone?.trim().isNotEmpty == true)
        'Phone: ${contact.verifiedPhone!.trim()}'
      else if (contact.mobile?.trim().isNotEmpty == true)
        'Phone: ${contact.mobile!.trim()}'
      else if (contact.phone?.trim().isNotEmpty == true)
        'Phone: ${contact.phone!.trim()}',
      if (contact.appIds.isNotEmpty)
        'Applications: ${contact.appIds.join(', ')}',
      'Status: ${contact.status}',
      if (contact.companyName?.trim().isNotEmpty == true)
        'Company: ${contact.companyName!.trim()}',
      if (contact.email?.trim().isNotEmpty == true)
        'Email: ${contact.email!.trim()}',
      if (contact.verifiedEmail?.trim().isNotEmpty == true)
        'Verified email: ${contact.verifiedEmail!.trim()}',
      if (contact.idNumber?.trim().isNotEmpty == true)
        'ID: ${contact.idNumber!.trim()}',
    ];
    final description = details.join('   ·   ');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.dividerColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Tooltip(
                  message: description,
                  child: Text(
                    description,
                    maxLines: desktop ? 1 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                onPressed: busy ? null : onRemove,
                icon: const Icon(Icons.person_remove_outlined, size: 16),
                label: Text(desktop ? 'Remove from app' : 'Remove'),
                style: TextButton.styleFrom(
                  foregroundColor: theme.colorScheme.error,
                  visualDensity: VisualDensity.compact,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactActionsMenu extends StatelessWidget {
  const _ContactActionsMenu({
    required this.busy,
    required this.active,
    required this.onAddresses,
    required this.onProfiles,
    required this.onEdit,
    required this.onRemove,
  });

  final bool busy;
  final bool active;
  final VoidCallback onAddresses;
  final VoidCallback onProfiles;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Contact actions',
      enabled: !busy,
      onSelected: (choice) {
        switch (choice) {
          case 'profiles':
            onProfiles();
          case 'addresses':
            onAddresses();
          case 'edit':
            onEdit();
          case 'remove':
            onRemove();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem<String>(
          value: 'profiles',
          enabled: active,
          child: const Text('Linked Health Profiles'),
        ),
        PopupMenuItem<String>(
          value: 'addresses',
          enabled: active,
          child: const Text('Delivery addresses'),
        ),
        PopupMenuItem<String>(
          value: 'edit',
          enabled: active,
          child: const Text('Edit contact'),
        ),
        const PopupMenuItem<String>(
          value: 'remove',
          child: Text('Remove from this app'),
        ),
      ],
    );
  }
}
