// lib/features/records/health_profiles/widgets/profile_details_screen.dart

import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_form_dialog.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_labels.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_associations_section.dart';
import 'package:firebase_auth/firebase_auth.dart' as fb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/health_profiles/profile_models.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_card.dart';

/// UI-only permission check. The API independently verifies the Firebase token.
/// Only the canonical `superadmin` claim grants platform authority.
final healthProfileSuperadminClaimProvider = FutureProvider.autoDispose<bool>((
  ref,
) async {
  final user = fb.FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  final token = await user.getIdTokenResult(true);
  return token.claims?['superadmin'] == true;
});

class ProfileDetailsScreen extends ConsumerStatefulWidget {
  const ProfileDetailsScreen({
    super.key,
    required this.profile,
    this.accountNumber,
    this.memberMode,
    this.allowExplicitContactLink = false,
    this.canReviewPurgeDependencies = false,
  });

  final Profile profile;

  /// Member mode passes this so refresh/update remains scoped.
  final String? accountNumber;
  final bool? memberMode;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  /// Retained for compatibility with existing ProfilesScreen callers.
  /// Review visibility now uses the verified Firebase superadmin claim directly;
  /// this caller-provided flag does not grant permissions.
  final bool canReviewPurgeDependencies;

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

  Future<bool> _confirmAction({
    required String title,
    required String message,
    required String action,
  }) async {
    final value = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      ),
    );
    return value == true;
  }

  Future<void> _deactivateProfile(Profile profile) async {
    final confirmed = await _confirmAction(
      title: 'Deactivate Health Profile',
      message:
          'Deactivate ${profile.fullName}? The profile and its history '
          'will be retained, but existing Contact associations will be disabled.',
      action: 'Deactivate',
    );
    if (!confirmed || !mounted) return;
    try {
      await _controller.deactivate(profile.profileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health Profile deactivated')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showErrorFromState();
    }
  }

  Future<void> _reactivateProfile(Profile profile) async {
    final confirmed = await _confirmAction(
      title: 'Reactivate Health Profile',
      message:
          'Reactivate ${profile.fullName}? Previously deactivated '
          'Contact associations will not be restored automatically.',
      action: 'Reactivate',
    );
    if (!confirmed || !mounted) return;
    try {
      await _controller.reactivate(profile.profileId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health Profile reactivated')),
      );
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) _showErrorFromState();
    }
  }

  Future<void> _reviewDeletionDependencies(Profile profile) async {
    try {
      final report = await ref.read(profilesServiceProvider)
          .inspectPurgeDependencies(profile.profileId);
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Permanent deletion review'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Health Profile ${report.profileId}'),
                  const SizedBox(height: 12),
                  Text(report.canPurge
                      ? 'No technical blockers detected. Retention review is still required.'
                      : 'Permanent deletion is blocked by the backend.'),
                  for (final entry in report.blockers.entries)
                    if (entry.value) Text('Blocked: ${entry.key.replaceAll('_', ' ')}'),
                  if (report.references.values.any((found) => found)) ...[
                    const SizedBox(height: 12),
                    const Text('Independent or historical references retained:'),
                    for (final entry in report.references.entries)
                      if (entry.value) Text('• ${entry.key.replaceAll('_', ' ')}'),
                  ],
                  if (report.unchecked.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    const Text('Manual reviews still required:'),
                    for (final item in report.unchecked)
                      Text('• ${item.replaceAll('_', ' ')}'),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Close')),
          ],
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Dependency review unavailable: $error')),
      );
    }
  }

  Future<void> _permanentlyDeleteProfile(Profile profile) async {
    if (_memberMode || widget.allowExplicitContactLink == false || profile.isActive) return;
    final report = await ref.read(profilesServiceProvider)
        .inspectPurgeDependencies(profile.profileId);
    if (!mounted) return;
    if (!report.canPurge) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Deletion blocked. Review profile dependencies.')),
      );
      await _reviewDeletionDependencies(profile);
      return;
    }
    final idController = TextEditingController();
    final reasonController = TextEditingController();
    var reviewed = false;
    try {
      final approved = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (context, update) => AlertDialog(
            title: const Text('Permanently delete Health Profile'),
            content: SizedBox(
              width: 480,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('This permanently removes ${profile.profileId}. '
                        'Independent medical, financial and audit records remain.'),
                    const SizedBox(height: 12),
                    Text('Type ${profile.profileId} to confirm:'),
                    TextField(
                      controller: idController,
                      onChanged: (_) => update(() {}),
                      decoration: const InputDecoration(labelText: 'Health Profile ID'),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: reasonController,
                      onChanged: (_) => update(() {}),
                      maxLines: 3,
                      decoration: const InputDecoration(labelText: 'Reason (at least 10 characters)'),
                    ),
                    CheckboxListTile(
                      value: reviewed,
                      onChanged: (value) => update(() => reviewed = value ?? false),
                      title: const Text('I have reviewed clinical retention, independent records and legal requirements.'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: reviewed && idController.text.trim() == profile.profileId &&
                        reasonController.text.trim().length >= 10
                    ? () => Navigator.of(dialogContext).pop(true)
                    : null,
                child: const Text('Delete permanently'),
              ),
            ],
          ),
        ),
      );
      if (approved != true || !mounted) return;
      await _controller.permanentlyDelete(
        profile.profileId,
        confirmation: idController.text,
        reason: reasonController.text,
        retentionReviewed: reviewed,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Health Profile permanently deleted')),
      );
      Navigator.of(context).pop();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Permanent deletion failed: $error')),
      );
    } finally {
      idController.dispose();
      reasonController.dispose();
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
    final isPlatformSuperadmin =
        ref.watch(healthProfileSuperadminClaimProvider).valueOrNull == true;
    final canReviewDeletion =
        !_memberMode && widget.allowExplicitContactLink && isPlatformSuperadmin;
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
            onPressed: state.isSaving || !visibleProfile.isActive
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
                _ProfileClinicalCard(profile: visibleProfile),
                const SizedBox(height: AppShape.gap14),
                if (visibleProfile.isActive)
                  ProfileAssociationsSection(
                    profile: visibleProfile,
                    staffMode: widget.allowExplicitContactLink && !_memberMode,
                  )
                else
                  const AppCard(
                    child: Text(
                      'This profile is deactivated. Contact links and '
                      'family relationships are unavailable until reactivation. '
                      'Existing links must be reviewed separately.',
                    ),
                  ),
                if ((visibleProfile.notes ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: AppShape.gap14),
                  _ProfileNotesCard(notes: visibleProfile.notes!.trim()),
                ],
                const SizedBox(height: AppShape.gap24),
                if (widget.allowExplicitContactLink && !_memberMode)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: visibleProfile.isActive
                        ? TextButton.icon(
                            onPressed: state.isSaving
                                ? null
                                : () => _deactivateProfile(visibleProfile),
                            icon: const Icon(Icons.pause_circle_outline),
                            label: const Text('Deactivate Health Profile'),
                          )
                        : Wrap(
                            spacing: 12,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              FilledButton.icon(
                                onPressed: state.isSaving
                                    ? null
                                    : () => _reactivateProfile(visibleProfile),
                                icon: const Icon(Icons.restore),
                                label: const Text('Reactivate'),
                              ),
                              if (canReviewDeletion)
                                OutlinedButton.icon(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _reviewDeletionDependencies(
                                          visibleProfile,
                                        ),
                                  icon: const Icon(Icons.fact_check_outlined),
                                  label: const Text(
                                    'Review deletion eligibility',
                                  ),
                                ),
                              if (canReviewDeletion)
                                TextButton.icon(
                                  onPressed: state.isSaving
                                      ? null
                                      : () => _permanentlyDeleteProfile(visibleProfile),
                                  icon: const Icon(Icons.delete_forever_outlined),
                                  label: const Text('Delete permanently'),
                                ),
                            ],
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

class _ProfileClinicalCard extends StatelessWidget {
  const _ProfileClinicalCard({required this.profile});
  final Profile profile;
  @override
  Widget build(BuildContext context) => AppCard(
    title: 'Medical history',
    icon: Icons.medical_information_outlined,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(label: 'Allergy status', value: profile.allergyStatus.name),
        for (final a in profile.allergies)
          _InfoRow(
            label: 'Allergy',
            value:
                '${a.substance}${a.reaction == null ? '' : ' — ${a.reaction}'}',
          ),
        for (final c in profile.conditions)
          _InfoRow(label: 'Condition', value: '${c.name} (${c.status.name})'),
        for (final v in profile.vaccinations)
          _InfoRow(
            label: 'Vaccination',
            value: '${v.vaccineName} (${v.status.name})',
          ),
        _InfoRow(
          label: 'Past medical history',
          value: profile.pastMedicalHistory,
        ),
        _InfoRow(label: 'Surgical history', value: profile.surgicalHistory),
        _InfoRow(label: 'Family history', value: profile.familyHistory),
        _InfoRow(label: 'Social history', value: profile.socialHistory),
        _InfoRow(
          label: 'Current medications',
          value: profile.currentMedications,
        ),
      ],
    ),
  );
}
