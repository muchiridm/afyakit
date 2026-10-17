// lib/features/records/health_profiles/widgets/profile_details_screen.dart

import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_form_dialog.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profiles_screen_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({
    super.key,
    required this.profile,
    this.accountNumber,
    this.memberMode,
    this.allowExplicitContactLink = false,
  });

  final Profile profile;

  /// Member mode passes this so refresh/update remains scoped.
  final String? accountNumber;
  final bool? memberMode;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  @override
  ConsumerState<ProfileDetailsScreen> createState() =>
      _ProfileDetailsScreenState();
}

class _ProfileDetailsScreenState extends ConsumerState<ProfileDetailsScreen> {
  String? get _contactScope {
    final id = widget.accountNumber?.trim();
    if (id == null || id.isEmpty) return null;
    return id;
  }

  bool get _memberMode => widget.memberMode ?? !widget.allowExplicitContactLink;

  ProfilesScope get _scope {
    return ProfilesScope(
      accountNumber: _contactScope,
      memberMode: _memberMode,
      allowExplicitContactLink: widget.allowExplicitContactLink,
    );
  }

  ProfilesController get _controller {
    return ref.read(profilesControllerProvider(_scope).notifier);
  }

  ProfilesState get _state {
    return ref.watch(profilesControllerProvider(_scope));
  }

  Profile? get _currentProfile {
    final profileId = widget.profile.profileId.trim();
    final state = _state;

    for (final profile in state.items) {
      if (profile.profileId.trim() == profileId) {
        return profile;
      }
    }

    // Never display unverified route arguments in member mode.
    return _memberMode ? null : widget.profile;
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
    if (_memberMode && profile == null) {
      return AppPage(
        title: 'Health profile',
        showBack: true,
        maxWidth: AppLayout.contentMaxWidth,
        padding: AppLayout.pagePadding,
        scrollable: false,
        body: Center(
          child: state.isLoading
              ? const CircularProgressIndicator()
              : Text(
                  state.error ??
                      'This profile is not available to your account.',
                ),
        ),
      );
    }
    final visibleProfile = profile!;

    return AppPage(
      title: visibleProfile.fullName,
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
            onPressed: state.isSaving
                ? null
                : () => _openEditDialog(visibleProfile),
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
                _ProfileHeaderCard(profile: visibleProfile),
                const SizedBox(height: AppShape.gap14),
                _ProfileDemographicsCard(profile: visibleProfile),
                const SizedBox(height: AppShape.gap14),
                _ProfileAssociationsSection(
                  profile: visibleProfile,
                  staffMode: widget.allowExplicitContactLink && !_memberMode,
                ),
                if ((visibleProfile.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppShape.gap14),
                  _ProfileNotesCard(notes: visibleProfile.notes!.trim()),
                ],
                const SizedBox(height: AppShape.gap24),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: state.isSaving
                        ? null
                        : () => _deleteProfile(visibleProfile),
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

class _ProfileAssociationsSection extends ConsumerStatefulWidget {
  const _ProfileAssociationsSection({required this.profile, required this.staffMode});
  final Profile profile;
  final bool staffMode;
  @override
  ConsumerState<_ProfileAssociationsSection> createState() => _ProfileAssociationsSectionState();
}

class _ProfileAssociationsSectionState extends ConsumerState<_ProfileAssociationsSection> {
  Future<List<RelatedProfile>>? _related;
  Future<List<ProfileLinkedContact>>? _payers;
  @override
  void initState() { super.initState(); _reload(); }
  @override
  void didUpdateWidget(covariant _ProfileAssociationsSection old) {
    super.didUpdateWidget(old);
    if (old.profile.profileId != widget.profile.profileId || old.staffMode != widget.staffMode) _reload();
  }
  void _reload() {
    final service = ref.read(profilesServiceProvider);
    _related = service.listRelatedProfiles(widget.profile.profileId);
    _payers = widget.staffMode ? service.listLinkedPayers(widget.profile.profileId) : null;
  }
  void _refresh() { setState(_reload); }
  void _error(Object error) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.toString())));
  }

  Future<void> _addPayer() async {
    final accountCtl = TextEditingController();
    ProfileContactRelationship relationship = ProfileContactRelationship.other;
    try {
      final result = await showDialog<(String, ProfileContactRelationship)>(
        context: context,
        builder: (context) => StatefulBuilder(builder: (context, update) => AlertDialog(
          title: const Text('Link Native Contact'),
          content: Column(mainAxisSize: MainAxisSize.min, children: [
            TextField(controller: accountCtl,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Native Contact account', hintText: 'AC-XXXXXX')),
            DropdownButtonFormField<ProfileContactRelationship>(
              initialValue: relationship, decoration: const InputDecoration(labelText: 'Association'),
              items: ProfileContactRelationship.values.map((v) => DropdownMenuItem(value: v, child: Text(v.name))).toList(),
              onChanged: (v) { if (v != null) update(() => relationship = v); },
            ),
            const Text('This describes the patient relative to the Contact; linking does not automatically authorise access or payment.'),
          ]),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(onPressed: () {
              final account = accountCtl.text.trim().toUpperCase();
              if (!RegExp(r'^AC-[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{6}$').hasMatch(account)) return;
              Navigator.pop(context, (account, relationship));
            }, child: const Text('Link'))],
        )),
      );
      if (result == null) return;
      await ref.read(profilesServiceProvider).linkContact(widget.profile.profileId,
        ProfileContactLinkInput(accountNumber: result.$1, relationship: result.$2));
      if (mounted) _refresh();
    } catch (e) { _error(e); } finally { accountCtl.dispose(); }
  }

  Future<void> _editContactLink(ProfileLinkedContact contact) async {
    var relationship = contact.relationship;
    final updated = await showDialog<ProfileContactRelationship>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Edit Contact relationship'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(contact.contactDisplayName ?? contact.accountNumber),
              Text(contact.accountNumber),
              const SizedBox(height: 12),
              DropdownButtonFormField<ProfileContactRelationship>(
                initialValue: relationship,
                decoration: const InputDecoration(labelText: 'Patient is this Contact’s…'),
                items: ProfileContactRelationship.values
                    .map((value) => DropdownMenuItem(
                          value: value,
                          child: Text(ProfilesLabels.relationship(value)),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) setDialogState(() => relationship = value);
                },
              ),
              const SizedBox(height: 8),
              const Text('Changing a Self or family link changes the inferred Linked Profiles view.'),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
            FilledButton(
              onPressed: () => Navigator.pop(context, relationship),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (updated == null || updated == contact.relationship) return;
    try {
      await ref.read(profilesServiceProvider).linkContact(
        widget.profile.profileId,
        ProfileContactLinkInput(
          accountNumber: contact.accountNumber,
          relationship: updated,
        ),
      );
      if (mounted) _refresh();
    } catch (error) {
      _error(error);
    }
  }

  static String _relatedLabel(ProfileRelationship relationship) {
    return switch (relationship) {
      ProfileRelationship.spouse => 'Spouse',
      ProfileRelationship.parent => 'Parent',
      ProfileRelationship.child => 'Child',
      ProfileRelationship.guardian => 'Guardian',
      ProfileRelationship.ward => 'Ward',
      ProfileRelationship.sibling => 'Sibling',
      ProfileRelationship.other => 'Other',
    };
  }

  Future<void> _removePayer(ProfileLinkedContact payer) async {
    try {
      await ref.read(profilesServiceProvider).delinkContact(
        profileId: widget.profile.profileId, accountNumber: payer.accountNumber);
      if (mounted) _refresh();
    } catch (e) { _error(e); }
  }

  @override
  Widget build(BuildContext context) => Column(children: [
    AppCard(title: 'Linked Profiles', icon: Icons.people_outline,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(dense: true, title: Text(widget.profile.fullName),
          subtitle: Text(widget.profile.profileId), trailing: const Text('Current profile')),
        FutureBuilder<List<RelatedProfile>>(future: _related, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
          if (snapshot.hasError) return Text('Linked profiles unavailable: ${snapshot.error}');
          final list = snapshot.data ?? const <RelatedProfile>[];
          if (list.isEmpty) return const Text('No additional profiles linked.');
          return Column(children: list.map((person) => ListTile(dense: true,
            title: Text(person.fullName),
            subtitle: Text(person.profileId),
             trailing: Text(_relatedLabel(person.relationship)),
          )).toList());
        }),
         if (widget.staffMode) const Padding(
           padding: EdgeInsets.only(top: 8),
           child: Text('Inferred from Native Contact relationships. To change a family relationship, edit the corresponding Contact link below.'),
         ),
      ])),
    const SizedBox(height: AppShape.gap14),
    if (widget.staffMode) AppCard(title: 'Linked Contacts / Payers', icon: Icons.account_balance_wallet_outlined,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        FutureBuilder<List<ProfileLinkedContact>>(future: _payers, builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) return const LinearProgressIndicator();
          if (snapshot.hasError) return Text('Linked payers unavailable: ${snapshot.error}');
          final list = snapshot.data ?? const <ProfileLinkedContact>[];
          if (list.isEmpty) return const Text('No Native Contacts linked.');
          return Column(children: list.map((payer) => ListTile(dense: true,
            title: Text(payer.contactDisplayName ?? payer.accountNumber),
            subtitle: Text('${payer.accountNumber} · ${ProfilesLabels.profilePerspectiveRelationship(payer.relationship)}'),
            trailing: payer.isActive
                ? Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined),
                      tooltip: 'Edit relationship',
                      onPressed: () => _editContactLink(payer),
                    ),
                    IconButton(
                      icon: const Icon(Icons.link_off),
                      tooltip: 'Unlink Contact',
                      onPressed: () => _removePayer(payer),
                    ),
                  ])
                : const Text('Inactive'),
          )).toList());
        }),
        TextButton.icon(onPressed: _addPayer, icon: const Icon(Icons.add_link),
          label: const Text('Link Native Contact')),
      ])),
  ]);
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
