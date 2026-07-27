// lib/features/clinical/profiles/widgets/profile_details_screen.dart

import 'package:afyakit/features/clinical/profiles/controllers/profiles_controller.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profile_form_dialog.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({
    super.key,
    required this.profile,
    this.contactId,
    this.allowExplicitContactLink = false,
  });

  final Profile profile;

  /// Member mode passes this so refresh/update remains scoped.
  final String? contactId;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _PatientDetailsScreenState();
}

class _PatientDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  String? get _contactScope {
    final id = widget.contactId?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  ProfilesScope get _scope {
    return ProfilesScope(
      contactId: _contactScope,
      allowExplicitContactLink: widget.allowExplicitContactLink,
    );
  }

  ProfilesController get _controller {
    return ref.read(profilesControllerProvider(_scope).notifier);
  }

  ProfilesState get _state {
    return ref.watch(profilesControllerProvider(_scope));
  }

  Profile get _patient {
    final patientId = widget.profile.profileId.trim();
    final state = _state;

    for (final patient in state.items) {
      if (patient.profileId.trim() == patientId) {
        return patient;
      }
    }

    return widget.profile;
  }

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _controller.load();
    });
  }

  Future<void> _openEditDialog(Profile patient) async {
    final input = await showDialog<ProfileUpsertInput>(
      context: context,
      builder: (_) => ProfileFormDialog(
        initial: patient,
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      await _controller.update(patient.profileId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile updated')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _deletePatient(Profile patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          widget.allowExplicitContactLink
              ? 'Delete patient profile'
              : 'Remove patient profile',
        ),
        content: Text(
          widget.allowExplicitContactLink
              ? 'Delete ${patient.fullName}?'
              : 'Remove ${patient.fullName} from your linked profiles?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(widget.allowExplicitContactLink ? 'Delete' : 'Remove'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await _controller.remove(patient.profileId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.allowExplicitContactLink
                ? 'Patient profile deleted'
                : 'Patient profile removed',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  void _showErrorFromState() {
    final error = ref.read(profilesControllerProvider(_scope)).error;
    if (error == null || error.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  @override
  Widget build(BuildContext context) {
    final patient = _patient;
    final state = _state;

    return AppPage(
      title: patient.fullName,
      showBack: true,
      maxWidth: AppLayout.contentMaxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.isLoading ? null : _controller.refreshAll,
          icon: const Icon(Icons.refresh),
        ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: state.isSaving ? null : () => _openEditDialog(patient),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('Edit'),
          ),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _PatientHeaderCard(patient: patient),
                const SizedBox(height: AppShape.gap14),
                _PatientDemographicsCard(patient: patient),
                const SizedBox(height: AppShape.gap14),
                _PatientLinkedContactsCard(patient: patient),
                if ((patient.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppShape.gap14),
                  _PatientNotesCard(notes: patient.notes!.trim()),
                ],
                const SizedBox(height: AppShape.gap24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => _deletePatient(patient),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      widget.allowExplicitContactLink
                          ? 'Delete patient profile'
                          : 'Remove patient profile',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PatientHeaderCard extends StatelessWidget {
  const _PatientHeaderCard({required this.patient});

  final Profile patient;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 28, child: Text(_initials(patient.fullName))),
          const SizedBox(width: AppShape.gap14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  patient.fullName,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  patient.profileId,
                  style: t.bodySmall?.copyWith(
                    color: scheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: AppShape.gap8),
                Wrap(
                  spacing: AppShape.gap8,
                  runSpacing: AppShape.gap8,
                  children: [
                    _StatusChip(
                      label: patient.isActive ? 'Active' : 'Inactive',
                      active: patient.isActive,
                    ),
                    if (patient.relationship != null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          ProfilesLabels.relationship(patient.relationship!),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _initials(String value) {
    final parts = value
        .trim()
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return '?';
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

class _PatientDemographicsCard extends StatelessWidget {
  const _PatientDemographicsCard({required this.patient});

  final Profile patient;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Details',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _InfoRow(label: 'Date of birth', value: patient.dob),
          _InfoRow(label: 'Gender', value: _genderLabel(patient.gender)),
          _InfoRow(label: 'Phone', value: patient.phone),
          _InfoRow(label: 'Email', value: patient.email),
          _InfoRow(label: 'National ID', value: patient.nationalId),
          _InfoRow(label: 'Primary contact', value: patient.contactDisplayName),
          _InfoRow(label: 'Contact ID', value: patient.contactId),
        ],
      ),
    );
  }

  static String? _genderLabel(ProfileGender? gender) {
    if (gender == null) return null;

    return switch (gender) {
      ProfileGender.male => 'Male',
      ProfileGender.female => 'Female',
      ProfileGender.other => 'Other',
      ProfileGender.unknown => 'Unknown',
    };
  }
}

class _PatientLinkedContactsCard extends StatelessWidget {
  const _PatientLinkedContactsCard({required this.patient});

  final Profile patient;

  @override
  Widget build(BuildContext context) {
    final links = patient.linkedContacts;

    return AppCard(
      title: 'Linked contacts',
      icon: Icons.link_outlined,
      child: links.isEmpty
          ? const Text('No linked contacts.', style: TextStyle(fontSize: 12))
          : Column(
              children: [
                for (int i = 0; i < links.length; i++) ...[
                  _LinkedContactTile(link: links[i]),
                  if (i != links.length - 1) const Divider(height: 16),
                ],
              ],
            ),
    );
  }
}

class _LinkedContactTile extends StatelessWidget {
  const _LinkedContactTile({required this.link});

  final ProfileLinkedContact link;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final title = (link.contactDisplayName ?? '').trim().isNotEmpty
        ? link.contactDisplayName!.trim()
        : link.contactId;

    final subtitleParts = <String>[
      ProfilesLabels.relationship(link.relationship),
      link.isActive ? 'Active' : 'Inactive',
    ];

    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        Icons.account_circle_outlined,
        color: scheme.onSurfaceVariant,
      ),
      title: Text(title),
      subtitle: Text(subtitleParts.join(' • ')),
    );
  }
}

class _PatientNotesCard extends StatelessWidget {
  const _PatientNotesCard({required this.notes});

  final String notes;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Notes',
      icon: Icons.notes_outlined,
      child: Text(notes),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    final clean = (value ?? '').trim();
    if (clean.isEmpty) return const SizedBox.shrink();

    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppShape.gap10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: t.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              clean,
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.active});

  final String label;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Chip(
      label: Text(label),
      visualDensity: VisualDensity.compact,
      backgroundColor: active
          ? scheme.primaryContainer.withOpacity(0.55)
          : scheme.errorContainer.withOpacity(0.55),
    );
  }
}
