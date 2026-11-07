// lib/features/records/health_profiles/widgets/member_self_profile_screen.dart
// Personal, cross-application Health Profile entry for Occupational Health.
// Identity and uniqueness MUST also be enforced by the backend.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/profiles_service.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_details_screen.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_form_dialog.dart';

class MemberSelfProfileScreen extends ConsumerStatefulWidget {
  const MemberSelfProfileScreen({super.key, required this.accountNumber});

  /// The current authenticated member's canonical Native Contact account.
  /// The backend must derive and verify this from the session as well.
  final String accountNumber;

  @override
  ConsumerState<MemberSelfProfileScreen> createState() =>
      _MemberSelfProfileScreenState();
}

class _MemberSelfProfileScreenState
    extends ConsumerState<MemberSelfProfileScreen> {
  bool _loading = true;
  bool _creating = false;
  String? _error;
  Profile? _profile;
  bool _hasUnverifiedResults = false;

  String get _account => widget.accountNumber.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _load();
    });
  }

  // The relationship filter must be resolved against tenant-wide canonical
  // profile links, not the current application's profile enrolments.
  Future<List<Profile>> _readSelfProfiles(ProfilesService service) async {
    final results = await service.list(
      accountNumber: _account,
      relationship: ProfileContactRelationship.self,
      // Include inactive links too: they must not trigger duplicate creation.
      perPage: 100,
    );
    return results;
  }

  bool _belongsToSelf(Profile profile) {
    if (!profile.isActive) return false;
    if (profile.relationship == ProfileContactRelationship.self &&
        profile.accountNumber?.trim().toUpperCase() == _account) {
      return true;
    }
    return profile.activeLinkedContacts.any(
      (link) =>
          link.accountNumber.trim().toUpperCase() == _account &&
          link.relationship == ProfileContactRelationship.self,
    );
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
      _hasUnverifiedResults = false;
    });
    try {
      final service = await ref.read(profilesServiceReadyProvider.future);
      final results = await _readSelfProfiles(service);
      final verified = results.where(_belongsToSelf).toList(growable: false);
      if (!mounted) return;
      setState(() {
        _profile = verified.isEmpty ? null : verified.first;
        // Do not offer creation if a record was returned whose self-link
        // cannot be verified from the API response, or duplicates exist.
        _hasUnverifiedResults = results.length != verified.length ||
            verified.length > 1;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to check your linked profile: $error';
        _loading = false;
      });
    }
  }

  Future<void> _openDetails() async {
    final profile = _profile;
    if (profile == null || !_belongsToSelf(profile)) return;
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailsScreen(
          profile: profile,
          accountNumber: _account,
          memberMode: true,
          allowExplicitContactLink: false,
        ),
      ),
    );
    if (mounted) await _load();
  }

  Future<void> _createSelfProfile() async {
    if (_loading || _creating || _profile != null ||
        _hasUnverifiedResults || _error != null) return;
    setState(() => _creating = true);
    try {
      final service = await ref.read(profilesServiceReadyProvider.future);
      // Recheck immediately before showing creation; a profile could have
      // been linked from another app since the page was first opened.
      final before = await _readSelfProfiles(service);
      if (before.isNotEmpty) {
        if (mounted) await _load();
        return;
      }
      if (!mounted) return;
      final input = await showDialog<ProfileUpsertInput>(
        context: context,
        builder: (_) => const ProfileFormDialog(
          initialRelationship: ProfileContactRelationship.self,
          allowExplicitContactLink: false,
        ),
      );
      if (input == null || !mounted) return;
      if (input.relationship != ProfileContactRelationship.self) {
        throw StateError('Only a Self profile may be created here.');
      }
      // Check again after the dialog, in case a link was created while open.
      final after = await _readSelfProfiles(service);
      if (after.isNotEmpty) {
        if (mounted) await _load();
        return;
      }
      await service.create(ProfileUpsertInput(
        fullName: input.fullName,
        dob: input.dob,
        gender: input.gender,
        accountNumber: _account,
        relationship: ProfileContactRelationship.self,
        phone: input.phone,
        email: input.email,
        nationalId: input.nationalId,
        notes: input.notes,
        pastMedicalHistory: input.pastMedicalHistory,
        surgicalHistory: input.surgicalHistory,
        familyHistory: input.familyHistory,
        socialHistory: input.socialHistory,
        currentMedications: input.currentMedications,
        allergyStatus: input.allergyStatus,
        allergies: input.allergies,
        vaccinations: input.vaccinations,
        conditions: input.conditions,
      ));
      if (mounted) await _load();
    } catch (error) {
      // A server-side duplicate-link / ownership rejection is expected
      // if another device creates the profile concurrently.
      if (mounted) {
        setState(() => _error = 'Could not create your self profile: $error');
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final profile = _profile;
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _creating ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: _load,
                            icon: const Icon(Icons.refresh),
                            label: const Text('Retry'),
                          ),
                        ],
                      )
                    : _hasUnverifiedResults
                        ? const Center(
                            child: Text(
                              'Your self-profile link needs review. '
                              'Please contact support; no new profile '
                              'will be created until it is resolved.',
                              textAlign: TextAlign.center,
                            ),
                          )
                        : profile != null
                            ? Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_outline, size: 48,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(height: 12),
                                  Text(profile.fullName,
                                      style: theme.textTheme.titleLarge,
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 8),
                                  const Text('Your linked health profile',
                                      textAlign: TextAlign.center),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: _openDetails,
                                    icon: const Icon(Icons.open_in_new),
                                    label: const Text('Open My Profile'),
                                  ),
                                ],
                              )
                            : Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.person_add_alt_1_outlined,
                                      size: 48,
                                      color: theme.colorScheme.primary),
                                  const SizedBox(height: 12),
                                  const Text(
                                    'No self-linked health profile was found.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 8),
                                  const Text(
                                    'If you already created a profile in '
                                    'another AfyaKit application, it should '
                                    'appear here automatically.',
                                    textAlign: TextAlign.center,
                                  ),
                                  const SizedBox(height: 20),
                                  FilledButton.icon(
                                    onPressed: _creating ? null : _createSelfProfile,
                                    icon: const Icon(Icons.add),
                                    label: Text(_creating
                                        ? 'Creating…'
                                        : 'Create My Profile'),
                                  ),
                                ],
                              ),
          ),
        ),
      ),
    );
  }
}
