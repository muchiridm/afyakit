import 'package:flutter/material.dart';
import '../models/native_contact.dart';

/// Responsive, expandable and read-only Native Contact tile.
///
/// Parent controls expansion so only one tile needs to be open at a time.
/// All mutations and navigation remain the parent's responsibility.
class NativeContactTile extends StatelessWidget {
  const NativeContactTile({
    super.key,
    required this.contact,
    required this.expanded,
    required this.onToggle,
    required this.onAddresses,
    required this.onEdit,
    required this.onRemove,
    this.busy = false,
  });
  final NativeContact contact;
  final bool expanded;
  final bool busy;
  final VoidCallback onToggle;
  final VoidCallback onAddresses;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  bool get _hasAccountNumber => (contact.accountNumber ?? '').trim().isNotEmpty;
  bool get _active => contact.status.trim().toLowerCase() == 'active';
  String get _primaryPhone {
    for (final value in [
      contact.verifiedPhone,
      contact.mobile,
      contact.phone,
    ]) {
      if (value != null && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
                    vertical: 12,
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
                          children: [
                            Text(
                              contact.displayName,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              [
                                if (_hasAccountNumber)
                                  contact.accountNumber!.trim(),
                                if (_primaryPhone.isNotEmpty) _primaryPhone,
                              ].join(' · '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (desktop) ...[
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
                          onPressed: busy ? null : onEdit,
                          icon: const Icon(Icons.edit_outlined, size: 18),
                          label: const Text('Edit'),
                        ),
                        const SizedBox(width: 4),
                      ] else ...[
                        _ContactActionsMenu(
                          busy: busy,
                          active: _active,
                          onAddresses: onAddresses,
                          onEdit: onEdit,
                          onRemove: onRemove,
                        ),
                      ],
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
    final details = <_DetailValue>[
      if (contact.companyName?.trim().isNotEmpty == true)
        _DetailValue('Company', contact.companyName!),
      if (contact.verifiedEmail?.trim().isNotEmpty == true)
        _DetailValue('Verified app email', contact.verifiedEmail!),
      if (contact.email?.trim().isNotEmpty == true)
        _DetailValue('Contact email', contact.email!),
      if (contact.verifiedPhone?.trim().isNotEmpty == true)
        _DetailValue('Verified phone', contact.verifiedPhone!),
      if (contact.phone?.trim().isNotEmpty == true)
        _DetailValue('Phone', contact.phone!),
      if (contact.mobile?.trim().isNotEmpty == true)
        _DetailValue('Mobile', contact.mobile!),
      if (contact.idNumber?.trim().isNotEmpty == true)
        _DetailValue('ID number', contact.idNumber!),
      if (contact.appIds.isNotEmpty)
        _DetailValue('Applications', contact.appIds.join(', ')),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Divider(height: 1, color: theme.dividerColor),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (details.isEmpty)
                Text(
                  'No additional contact details',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                )
              else
                LayoutBuilder(
                  builder: (context, constraints) {
                    final columns = constraints.maxWidth >= 560 ? 2 : 1;
                    const gap = 12.0;
                    final width =
                        (constraints.maxWidth - (columns - 1) * gap) / columns;
                    return Wrap(
                      spacing: gap,
                      runSpacing: 6,
                      children: [
                        for (final detail in details)
                          SizedBox(
                            width: width,
                            child: _CompactDetail(detail: detail),
                          ),
                      ],
                    );
                  },
                ),
              if (desktop) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Wrap(
                    spacing: 6,
                    children: [
                      TextButton.icon(
                        onPressed: busy ? null : onRemove,
                        icon: const Icon(
                          Icons.person_remove_outlined,
                          size: 16,
                        ),
                        label: const Text('Remove from app'),
                        style: TextButton.styleFrom(
                          foregroundColor: theme.colorScheme.error,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DetailValue {
  const _DetailValue(this.label, this.value);
  final String label;
  final String value;
}

class _CompactDetail extends StatelessWidget {
  const _CompactDetail({required this.detail});
  final _DetailValue detail;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 112,
            child: Text(
              detail.label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: SelectableText(
              detail.value.trim(),
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _ContactActionsMenu extends StatelessWidget {
  const _ContactActionsMenu({
    required this.busy,
    required this.active,
    required this.onAddresses,
    required this.onEdit,
    required this.onRemove,
  });
  final bool busy;
  final bool active;
  final VoidCallback onAddresses;
  final VoidCallback onEdit;
  final VoidCallback onRemove;
  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Contact actions',
      enabled: !busy,
      onSelected: (value) {
        switch (value) {
          case 'addresses':
            onAddresses();
          case 'edit':
            onEdit();
          case 'remove':
            onRemove();
        }
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: 'addresses',
          enabled: active,
          child: const Text('Delivery addresses'),
        ),
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'remove', child: Text('Remove from app')),
      ],
    );
  }
}
