// lib/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart

import 'package:afyakit/features/clinical/profiles/controllers/profiles_controller.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_link_request_models.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:flutter/material.dart';

class ProfilesLabels {
  const ProfilesLabels._();

  static const List<ProfileContactRelationship> selfLinkRelationships = [
    ProfileContactRelationship.self,
    ProfileContactRelationship.child,
    ProfileContactRelationship.spouse,
    ProfileContactRelationship.parent,
    ProfileContactRelationship.guardian,
  ];

  static const List<ProfileContactRelationship> payerRequestRelationships = [
    ProfileContactRelationship.insurance,
    ProfileContactRelationship.other,
  ];

  static const List<ProfileContactRelationship> staffLinkRelationships = [
    ProfileContactRelationship.self,
    ProfileContactRelationship.child,
    ProfileContactRelationship.spouse,
    ProfileContactRelationship.parent,
    ProfileContactRelationship.guardian,
    ProfileContactRelationship.insurance,
    ProfileContactRelationship.other,
  ];

  static String relationship(ProfileContactRelationship value) {
    switch (value) {
      case ProfileContactRelationship.self:
        return 'Self';
      case ProfileContactRelationship.child:
        return 'Child';
      case ProfileContactRelationship.spouse:
        return 'Spouse';
      case ProfileContactRelationship.parent:
        return 'Parent';
      case ProfileContactRelationship.guardian:
        return 'Guardian';
      case ProfileContactRelationship.insurance:
        return 'Insurance';
      case ProfileContactRelationship.other:
        return 'Other payer/contact';
    }
  }

  static String gender(ProfileGender value) {
    switch (value) {
      case ProfileGender.male:
        return 'Male';
      case ProfileGender.female:
        return 'Female';
      case ProfileGender.other:
        return 'Other';
      case ProfileGender.unknown:
        return 'Unknown';
    }
  }

  static String status(ProfileLinkRequestStatus value) {
    switch (value) {
      case ProfileLinkRequestStatus.pendingOwnerApproval:
        return 'Pending owner approval';
      case ProfileLinkRequestStatus.pendingStaffApproval:
        return 'Pending staff approval';
      case ProfileLinkRequestStatus.approved:
        return 'Approved';
      case ProfileLinkRequestStatus.rejected:
        return 'Rejected';
      case ProfileLinkRequestStatus.cancelled:
        return 'Cancelled';
    }
  }

  static String approvalMode(ProfileLinkApprovalMode value) {
    switch (value) {
      case ProfileLinkApprovalMode.owner:
        return 'Owner approval';
      case ProfileLinkApprovalMode.staff:
        return 'Staff approval';
    }
  }

  static String nullable(String? value, {String fallback = '—'}) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? fallback : v;
  }
}

class ProfilesFilterBar extends StatelessWidget {
  const ProfilesFilterBar({
    super.key,
    required this.searchController,
    required this.contactIdController,
    required this.relationship,
    required this.isActive,
    required this.allowExplicitContactLink,
    required this.onSearchSubmitted,
    required this.onContactIdSubmitted,
    required this.onRelationshipChanged,
    required this.onStatusChanged,
    required this.onClearFilters,
  });

  final TextEditingController searchController;
  final TextEditingController contactIdController;
  final ProfileContactRelationship? relationship;
  final bool? isActive;
  final bool allowExplicitContactLink;

  final ValueChanged<String> onSearchSubmitted;
  final ValueChanged<String> onContactIdSubmitted;
  final ValueChanged<ProfileContactRelationship?> onRelationshipChanged;
  final ValueChanged<String?> onStatusChanged;
  final VoidCallback onClearFilters;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          SizedBox(
            width: 260,
            child: TextField(
              controller: searchController,
              decoration: const InputDecoration(
                labelText: 'Search profiles',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onSubmitted: onSearchSubmitted,
            ),
          ),
          if (allowExplicitContactLink)
            SizedBox(
              width: 220,
              child: TextField(
                controller: contactIdController,
                decoration: const InputDecoration(
                  labelText: 'Associated contact ID',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                onSubmitted: onContactIdSubmitted,
              ),
            ),
          SizedBox(
            width: 260,
            child: DropdownButtonFormField<ProfileContactRelationship?>(
              initialValue: relationship,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Relationship',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: [
                const DropdownMenuItem<ProfileContactRelationship?>(
                  value: null,
                  child: Text('All', overflow: TextOverflow.ellipsis),
                ),
                ...ProfileContactRelationship.values.map(
                  (value) => DropdownMenuItem<ProfileContactRelationship?>(
                    value: value,
                    child: Text(
                      ProfilesLabels.relationship(value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
              selectedItemBuilder: (context) {
                return [
                  const Text('All', overflow: TextOverflow.ellipsis),
                  ...ProfileContactRelationship.values.map(
                    (value) => Text(
                      ProfilesLabels.relationship(value),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ];
              },
              onChanged: onRelationshipChanged,
            ),
          ),
          SizedBox(
            width: 160,
            child: DropdownButtonFormField<String>(
              initialValue: isActive == null
                  ? 'all'
                  : (isActive! ? 'active' : 'inactive'),
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Status',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: const [
                DropdownMenuItem(
                  value: 'all',
                  child: Text('All', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'active',
                  child: Text('Active', overflow: TextOverflow.ellipsis),
                ),
                DropdownMenuItem(
                  value: 'inactive',
                  child: Text('Inactive', overflow: TextOverflow.ellipsis),
                ),
              ],
              onChanged: onStatusChanged,
            ),
          ),
          OutlinedButton(
            onPressed: onClearFilters,
            child: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class ProfilesErrorBanner extends StatelessWidget {
  const ProfilesErrorBanner({super.key, required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Material(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              Icon(
                Icons.error_outline,
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  error,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ProfileCard extends StatelessWidget {
  const ProfileCard({
    super.key,
    required this.patient,
    required this.state,
    required this.allowExplicitContactLink,
    required this.onLinkToSelf,
    required this.onRequestPayerLink,
    required this.onLinkContact,
    required this.onDelinkContact,
    required this.onEdit,
    required this.onDelete,
  });

  final Profile patient;
  final ProfilesState state;
  final bool allowExplicitContactLink;

  /// Kept for now because the parent screen still wires this callback.
  /// The card no longer exposes this as a per-patient action.
  final ValueChanged<Profile> onLinkToSelf;

  final ValueChanged<Profile> onRequestPayerLink;
  final ValueChanged<Profile> onLinkContact;
  final void Function(Profile patient, ProfileLinkedContact link)
  onDelinkContact;
  final ValueChanged<Profile> onEdit;
  final ValueChanged<Profile> onDelete;

  Widget _infoLine(String label, String value) {
    return Text('$label: $value');
  }

  Widget _linkedContactsView(BuildContext context) {
    if (patient.linkedContacts.isEmpty) {
      final contextualContact = patient.contactDisplayName ?? patient.contactId;

      return _infoLine(
        'Linked contacts',
        ProfilesLabels.nullable(contextualContact),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Linked contacts:'),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: patient.linkedContacts
              .map((link) {
                final title = link.contactDisplayName?.trim().isNotEmpty == true
                    ? link.contactDisplayName!.trim()
                    : link.contactId;

                final relationship = ProfilesLabels.relationship(
                  link.relationship,
                );

                final status = link.isActive ? 'Active' : 'Inactive';
                final label = '$title · $relationship · $status';

                if (!allowExplicitContactLink || state.isSaving) {
                  return Chip(
                    label: Text(label),
                    visualDensity: VisualDensity.compact,
                  );
                }

                return InputChip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                  avatar: const Icon(Icons.link_off, size: 16),
                  tooltip: 'Delink contact',
                  onPressed: link.isActive
                      ? () => onDelinkContact(patient, link)
                      : null,
                );
              })
              .toList(growable: false),
        ),
        if (allowExplicitContactLink)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: state.isSaving ? null : () => onLinkContact(patient),
              icon: const Icon(Icons.add_link),
              label: const Text('Link contact/payer'),
            ),
          ),
      ],
    );
  }

  Widget _contextualContactView(BuildContext context) {
    final contact = patient.contactDisplayName ?? patient.contactId;
    final relationship = patient.relationship;

    if (ProfilesLabels.nullable(contact).trim() == '—' &&
        relationship == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Text(
        'Current association: ${ProfilesLabels.nullable(contact)}'
        '${relationship == null ? '' : ' · ${ProfilesLabels.relationship(relationship)}'}',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final actions = <Widget>[
      if (!allowExplicitContactLink)
        IconButton(
          tooltip: 'Request payer',
          onPressed: state.isSaving ? null : () => onRequestPayerLink(patient),
          icon: const Icon(Icons.request_quote_outlined),
        ),
      if (allowExplicitContactLink)
        IconButton(
          tooltip: 'Link contact/payer',
          onPressed: state.isSaving ? null : () => onLinkContact(patient),
          icon: const Icon(Icons.add_link),
        ),
      IconButton(
        tooltip: 'Edit',
        onPressed: state.isSaving ? null : () => onEdit(patient),
        icon: const Icon(Icons.edit_outlined),
      ),
      IconButton(
        tooltip: 'Delete',
        onPressed: state.isSaving ? null : () => onDelete(patient),
        icon: const Icon(Icons.delete_outline),
      ),
    ];

    return Card(
      child: ListTile(
        title: Text(patient.fullName),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('ID', patient.profileId),
              _infoLine('DOB', ProfilesLabels.nullable(patient.dob)),
              _infoLine(
                'Gender',
                patient.gender == null
                    ? '—'
                    : ProfilesLabels.gender(patient.gender!),
              ),
              _infoLine('Phone', ProfilesLabels.nullable(patient.phone)),
              _infoLine('Email', ProfilesLabels.nullable(patient.email)),
              _infoLine(
                'National ID',
                ProfilesLabels.nullable(patient.nationalId),
              ),
              const SizedBox(height: 6),
              _linkedContactsView(context),
              _contextualContactView(context),
              const SizedBox(height: 6),
              _infoLine('Status', patient.isActive ? 'Active' : 'Inactive'),
            ],
          ),
        ),
        trailing: Wrap(spacing: 8, children: actions),
      ),
    );
  }
}

class RequestSummaryBox extends StatelessWidget {
  const RequestSummaryBox({super.key, required this.request});

  final ProfileLinkRequest request;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 680,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: DefaultTextStyle.merge(
            style: Theme.of(context).textTheme.bodySmall,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  request.profileDisplayName,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                Text('Patient ID: ${request.profileId}'),
                Text('Requested target: ${request.bestTargetLabel}'),
                Text(
                  'Relationship: ${ProfilesLabels.relationship(request.relationship)}',
                ),
                Text('Status: ${ProfilesLabels.status(request.status)}'),
                Text(
                  'Approval: ${ProfilesLabels.approvalMode(request.approvalMode)}',
                ),
                if (request.matchesCount != null)
                  Text('Identifier matches: ${request.matchesCount}'),
                if (request.reason?.trim().isNotEmpty == true)
                  Text('Reason: ${request.reason!.trim()}'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class ProfileLinkRequestCard extends StatelessWidget {
  const ProfileLinkRequestCard({
    super.key,
    required this.request,
    required this.state,
    required this.onApprove,
    required this.onReject,
  });

  final ProfileLinkRequest request;
  final ProfilesState state;
  final ValueChanged<ProfileLinkRequest> onApprove;
  final ValueChanged<ProfileLinkRequest> onReject;

  Widget _infoLine(String label, String value) {
    return Text('$label: $value');
  }

  @override
  Widget build(BuildContext context) {
    final pending = request.isPending;

    return Card(
      child: ListTile(
        title: Text(
          '${request.profileDisplayName} → ${request.bestTargetLabel}',
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoLine('Patient ID', request.profileId),
              _infoLine(
                'Relationship',
                ProfilesLabels.relationship(request.relationship),
              ),
              _infoLine('Status', ProfilesLabels.status(request.status)),
              _infoLine(
                'Approval',
                ProfilesLabels.approvalMode(request.approvalMode),
              ),
              if (request.matchesCount != null)
                _infoLine('Identifier matches', '${request.matchesCount}'),
              if (request.reason?.trim().isNotEmpty == true)
                _infoLine('Reason', request.reason!.trim()),
            ],
          ),
        ),
        trailing: pending
            ? Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    tooltip: 'Approve',
                    onPressed: state.isSaving ? null : () => onApprove(request),
                    icon: const Icon(Icons.check_circle_outline),
                  ),
                  IconButton(
                    tooltip: 'Reject',
                    onPressed: state.isSaving ? null : () => onReject(request),
                    icon: const Icon(Icons.cancel_outlined),
                  ),
                ],
              )
            : null,
      ),
    );
  }
}

class ProfileLinkRequestsPanel extends StatelessWidget {
  const ProfileLinkRequestsPanel({
    super.key,
    required this.state,
    required this.allowExplicitContactLink,
    required this.onRefresh,
    required this.onApprove,
    required this.onReject,
  });

  final ProfilesState state;
  final bool allowExplicitContactLink;
  final VoidCallback onRefresh;
  final ValueChanged<ProfileLinkRequest> onApprove;
  final ValueChanged<ProfileLinkRequest> onReject;

  @override
  Widget build(BuildContext context) {
    if (!allowExplicitContactLink && state.linkRequests.isEmpty) {
      return const SizedBox.shrink();
    }

    final title = allowExplicitContactLink
        ? 'Pending link requests'
        : 'My link requests';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: ExpansionTile(
        initiallyExpanded:
            allowExplicitContactLink && state.linkRequests.isNotEmpty,
        tilePadding: EdgeInsets.zero,
        title: Text(title),
        subtitle: Text(
          state.isLoadingLinkRequests
              ? 'Loading…'
              : '${state.linkRequests.length} request(s)',
        ),
        trailing: Wrap(
          spacing: 8,
          children: [
            if (state.isLoadingLinkRequests)
              const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            IconButton(
              tooltip: 'Refresh requests',
              onPressed: state.isLoadingLinkRequests ? null : onRefresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        children: [
          if (state.linkRequests.isEmpty)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('No link requests found'),
              ),
            )
          else
            ...state.linkRequests.map(
              (request) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: ProfileLinkRequestCard(
                  request: request,
                  state: state,
                  onApprove: onApprove,
                  onReject: onReject,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
