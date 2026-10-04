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
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
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

  Profile get _currentProfile {
    final profileId = widget.profile.profileId.trim();
    final state = _state;

    for (final profile in state.items) {
      if (profile.profileId.trim() == profileId) {
        return profile;
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

  Future<void> _openEditDialog(Profile profile) async {
    final input = await showDialog<ProfileUpsertInput>(
      context: context,
      builder: (_) => ProfileFormDialog(
        initial: profile,
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      await _controller.update(profile.profileId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Health Profile updated')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _deleteProfile(Profile profile) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(
          widget.allowExplicitContactLink
              ? 'Delete Health Profile'
              : 'Remove Health Profile',
        ),
        content: Text(
          widget.allowExplicitContactLink
              ? 'Delete ${profile.fullName}?'
              : 'Remove ${profile.fullName} from your linked profiles?',
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
      await _controller.remove(profile.profileId);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            widget.allowExplicitContactLink
                ? 'Health Profile deleted'
                : 'Health Profile removed',
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
    final profile = _currentProfile;
    final state = _state;

    return AppPage(
      title: profile.fullName,
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
            onPressed: state.isSaving ? null : () => _openEditDialog(profile),
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
                _ProfileHeaderCard(profile: profile),
                const SizedBox(height: AppShape.gap14),
                _ProfileDemographicsCard(profile: profile),
                const SizedBox(height: AppShape.gap14),
                _ProfileLinkedContactsCard(profile: profile),
                if ((profile.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppShape.gap14),
                  _ProfileNotesCard(notes: profile.notes!.trim()),
                ],
                const SizedBox(height: AppShape.gap24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => _deleteProfile(profile),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(
                      widget.allowExplicitContactLink
                          ? 'Delete Health Profile'
                          : 'Remove Health Profile',
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

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(radius: 28, child: Text(_initials(profile.fullName))),
          const SizedBox(width: AppShape.gap14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  profile.fullName,
                  style: t.titleLarge?.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                SelectableText(
                  profile.profileId,
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
                      label: profile.isActive ? 'Active' : 'Inactive',
                      active: profile.isActive,
                    ),
                    if (profile.relationship != null)
                      Chip(
                        visualDensity: VisualDensity.compact,
                        label: Text(
                          ProfilesLabels.relationship(profile.relationship!),
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

class _ProfileDemographicsCard extends StatelessWidget {
  const _ProfileDemographicsCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      title: 'Details',
      icon: Icons.badge_outlined,
      child: Column(
        children: [
          _InfoRow(label: 'Date of birth', value: profile.dob),
          _InfoRow(label: 'Gender', value: _genderLabel(profile.gender)),
          _InfoRow(label: 'Phone', value: profile.phone),
          _InfoRow(label: 'Email', value: profile.email),
          _InfoRow(label: 'National ID', value: profile.nationalId),
          _InfoRow(label: 'Primary contact', value: profile.contactDisplayName),
          _InfoRow(label: 'Contact ID', value: profile.contactId),
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

class _ProfileLinkedContactsCard extends StatelessWidget {
  const _ProfileLinkedContactsCard({required this.profile});

  final Profile profile;

  @override
  Widget build(BuildContext context) {
    final links = profile.linkedContacts;

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

class _ProfileNotesCard extends StatelessWidget {
  const _ProfileNotesCard({required this.notes});

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
