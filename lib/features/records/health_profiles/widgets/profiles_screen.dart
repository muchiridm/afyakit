// lib/features/records/health_profiles/widgets/profiles_screen.dart

import 'package:afyakit/features/records/health_profiles/profiles_controller.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_form_dialog.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_payer_link_dialog.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_payer_self_link_dialog.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profiles_screen_widgets.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_list_tile.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/health_profiles/profile_link_request_models.dart';
import 'package:afyakit/features/records/health_profiles/profile_models.dart';
import 'package:afyakit/features/records/health_profiles/widgets/profile_details_screen.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({
    super.key,
    this.accountNumber,
    this.memberMode,
    this.allowExplicitContactLink = false,
    this.selectionMode = false,
    this.selectionTitle,
    this.createOnOpen = false,
  });

  /// When provided, the screen is restricted to profiles linked to
  /// this contact.
  ///
  /// Member flows should always provide this value.
  final String? accountNumber;

  /// Explicit member mode. Defaults to member mode unless staff features are enabled.
  /// Does not authorise access; the backend must verify account ownership.
  final bool? memberMode;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  /// When true, tapping a profile returns that [Profile] through
  /// [Navigator.pop] instead of opening [ProfileDetailsScreen].
  final bool selectionMode;

  /// Optional title shown while selecting a profile.
  final String? selectionTitle;

  /// Opens the existing profile form once when this screen is first shown.
  ///
  /// Used by home quick actions so profile creation remains centralised here.
  final bool createOnOpen;

  @override
  ConsumerState<ProfilesScreen> createState() {
    return _ProfilesScreenState();
  }
}

class _ProfilesScreenState extends ConsumerState<ProfilesScreen> {
  late final TextEditingController _searchCtl;
  late final TextEditingController _accountNumberCtl;

  ProfileContactRelationship? _relationship;
  bool _createFlowOpened = false;

  double get _maxWidth => AppLayout.contentMaxWidth;

  String? get _contactScope {
    final id = widget.accountNumber?.trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return id;
  }

  bool get _memberMode => widget.memberMode ?? !widget.allowExplicitContactLink;

  bool get _missingMemberAccount => _memberMode && _contactScope == null;

  ProfilesScope get _scope {
    return ProfilesScope(
      accountNumber: _contactScope,
      memberMode: _memberMode,
      allowExplicitContactLink: widget.allowExplicitContactLink,
    );
  }

  bool get _isContactScoped => _memberMode || _contactScope != null;

  bool get _showMemberInfo =>
      _isContactScoped &&
      !widget.allowExplicitContactLink &&
      !widget.selectionMode;

  ProfilesController get _controller {
    return ref.read(profilesControllerProvider(_scope).notifier);
  }

  ProfilesState get _currentState {
    return ref.read(profilesControllerProvider(_scope));
  }

  @override
  void initState() {
    super.initState();

    _searchCtl = TextEditingController();
    _accountNumberCtl = TextEditingController(text: _contactScope ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_missingMemberAccount) return;

      final controller = _controller;

      await controller.load();

      if (!mounted) return;

      if (widget.createOnOpen) {
        await _openCreateDialogOnce();
      }

      if (!mounted) return;

      if (!widget.selectionMode) {
        await controller.loadLinkRequests(
          status: widget.allowExplicitContactLink
              ? ProfileLinkRequestStatus.pendingStaffApproval
              : null,
          resetStatus: !widget.allowExplicitContactLink,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldAccountNumber = oldWidget.accountNumber?.trim();
    final newAccountNumber = widget.accountNumber?.trim();

    if (oldAccountNumber == newAccountNumber &&
        oldWidget.memberMode == widget.memberMode &&
        oldWidget.allowExplicitContactLink == widget.allowExplicitContactLink &&
        oldWidget.selectionMode == widget.selectionMode &&
        oldWidget.createOnOpen == widget.createOnOpen) {
      return;
    }

    _accountNumberCtl.text = _contactScope ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_missingMemberAccount) return;
      await _controller.refreshAll();

      if (!mounted) return;

      if (widget.createOnOpen && !oldWidget.createOnOpen) {
        await _openCreateDialogOnce();
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _accountNumberCtl.dispose();

    super.dispose();
  }

  void _handleProfileTap(Profile profile) {
    if (widget.selectionMode) {
      Navigator.of(context).pop(profile);
      return;
    }

    _openProfileDetails(profile);
  }

  void _openProfileDetails(Profile profile) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailsScreen(
          profile: profile,
          memberMode: _memberMode,
          accountNumber: _contactScope,
          allowExplicitContactLink: widget.allowExplicitContactLink,
        ),
      ),
    );
  }

  Future<void> _openCreateDialogOnce() async {
    if (_createFlowOpened || !mounted || _missingMemberAccount) return;

    _createFlowOpened = true;

    await _openCreateDialog();
  }

  Future<void> _openCreateDialog() async {
    if (_missingMemberAccount) return;
    final input = await showDialog<ProfileUpsertInput>(
      context: context,
      builder: (_) => ProfileFormDialog(
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      final created = await _controller.create(input);

      if (!mounted) return;

      if (widget.selectionMode) {
        Navigator.of(context).pop(created);
        return;
      }

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile created')));
    } catch (_) {
      if (!mounted) return;

      _showErrorFromState();
    }
  }

  Future<void> _requestExistingProfile() async {
    if (!_memberMode || _missingMemberAccount || widget.selectionMode) return;
    final submission = await ExistingProfileLinkRequestDialog.show(context);
    if (submission == null || !mounted) return;
    try {
      await _controller.createLinkRequest(
        submission.profileId,
        submission.input,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Request submitted. A staff member must review it.'),
        ),
      );
      await _controller.loadLinkRequests(resetStatus: true);
    } catch (_) {
      if (mounted) _showErrorFromState();
    }
  }

  Future<void> _openApproveLinkRequestDialog(ProfileLinkRequest request) async {
    if (!widget.allowExplicitContactLink || widget.selectionMode) {
      return;
    }

    final input = await ProfilePayerLinkDialog.showApprove(
      context: context,
      request: request,
    );

    if (input == null || !mounted) return;

    try {
      await _controller.approvePayerLinkRequest(
        request,
        accountNumber: input.accountNumber,
        contactDisplayName: input.contactDisplayName,
        relationship: input.relationship,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link request approved')));
    } catch (_) {
      if (!mounted) return;

      _showErrorFromState();
    }
  }

  Future<void> _openRejectLinkRequestDialog(ProfileLinkRequest request) async {
    if (!widget.allowExplicitContactLink || widget.selectionMode) {
      return;
    }

    final input = await ProfilePayerLinkDialog.showReject(context: context);

    if (input == null || !mounted) return;

    try {
      await _controller.rejectLinkRequest(request.requestId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link request rejected')));
    } catch (_) {
      if (!mounted) return;

      _showErrorFromState();
    }
  }

  void _showErrorFromState() {
    final error = _currentState.error;

    if (error == null || error.trim().isEmpty) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  void _clearFilters(ProfilesController controller) {
    _searchCtl.clear();

    if (widget.allowExplicitContactLink && !_isContactScoped) {
      _accountNumberCtl.clear();
    } else {
      _accountNumberCtl.text = _contactScope ?? '';
    }

    setState(() {
      _relationship = null;
    });

    controller.clearFilters();
  }

  String get _title {
    if (widget.selectionMode) {
      final supplied = widget.selectionTitle?.trim();

      if (supplied != null && supplied.isNotEmpty) {
        return supplied;
      }

      return 'Select profile';
    }

    return widget.allowExplicitContactLink ? 'Profiles' : 'My profiles';
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;

    final state = ref.watch(profilesControllerProvider(scope));

    final controller = ref.read(profilesControllerProvider(scope).notifier);

    return AppPage(
      title: _title,
      showBack: true,
      maxWidth: _maxWidth,
      padding: AppLayout.pagePadding,
      scrollable: false,
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: state.isLoading ? null : controller.refreshAll,
          icon: const Icon(Icons.refresh),
        ),
        if (_memberMode && !widget.selectionMode)
          TextButton.icon(
            onPressed: state.isSaving || _missingMemberAccount
                ? null
                : _requestExistingProfile,
            icon: const Icon(Icons.add_link),
            label: const Text('Request existing'),
          ),
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: state.isSaving || _missingMemberAccount
                ? null
                : _openCreateDialog,
            icon: state.isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: const Text('Add profile'),
          ),
        ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (_missingMemberAccount)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text(
                      'Unable to identify your Native Contact account. Profiles cannot be loaded.',
                    ),
                  ),
                if (_showMemberInfo) ...[
                  const _MemberProfilesInfoCard(),
                  const SizedBox(height: 12),
                ],
                if (!widget.selectionMode)
                  ProfileLinkRequestsPanel(
                    state: state,
                    allowExplicitContactLink: widget.allowExplicitContactLink,
                    onRefresh: () {
                      controller.loadLinkRequests(
                        status: widget.allowExplicitContactLink
                            ? ProfileLinkRequestStatus.pendingStaffApproval
                            : null,
                        resetStatus: !widget.allowExplicitContactLink,
                      );
                    },
                    onApprove: _openApproveLinkRequestDialog,
                    onReject: _openRejectLinkRequestDialog,
                  ),
                if (widget.selectionMode) const _ProfileSelectionHint(),
                ProfilesFilterBar(
                  searchController: _searchCtl,
                  accountNumberController: _accountNumberCtl,
                  relationship: _relationship,
                  isActive: state.isActive,
                  allowExplicitContactLink:
                      widget.allowExplicitContactLink && !widget.selectionMode,
                  onSearchSubmitted: (value) {
                    controller.applyFilters(search: value);
                  },
                  onAccountNumberSubmitted: (value) {
                    if (!widget.allowExplicitContactLink ||
                        widget.selectionMode) {
                      return;
                    }

                    controller.applyFilters(accountNumber: value);
                  },
                  onRelationshipChanged: (value) {
                    setState(() {
                      _relationship = value;
                    });

                    controller.applyFilters(
                      relationship: value,
                      resetRelationship: value == null,
                    );
                  },
                  onStatusChanged: (value) {
                    if (value == 'all') {
                      controller.applyFilters(resetIsActive: true);
                    } else {
                      controller.applyFilters(isActive: value == 'active');
                    }
                  },
                  onClearFilters: () {
                    _clearFilters(controller);
                  },
                ),
                // Count the profiles in the current loaded/filtered list.
                // Do not present this as a tenant-wide total if the API paginates.
                if (!_missingMemberAccount && !state.isLoading)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '${state.items.length} ${state.items.length == 1 ? 'profile' : 'profiles'}',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ),
                if (state.error != null && state.error!.trim().isNotEmpty)
                  ProfilesErrorBanner(error: state.error!),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.items.isEmpty)
                  Padding(
                    padding: const EdgeInsets.all(32),
                    child: Center(
                      child: Text(
                        widget.selectionMode
                            ? 'No linked profiles found'
                            : 'No profiles found',
                      ),
                    ),
                  )
                else if (!_missingMemberAccount)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: state.items
                          .map(
                            (profile) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: ProfileListTile(
                                profile: profile,
                                selectionMode: widget.selectionMode,
                                onTap: () {
                                  _handleProfileTap(profile);
                                },
                              ),
                            ),
                          )
                          .toList(growable: false),
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

class _MemberProfilesInfoCard extends StatelessWidget {
  const _MemberProfilesInfoCard();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.family_restroom_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Create a separate profile for yourself and each dependant; choose the relationship explicitly. '
                'Prescriptions, health measurements, and other clinical records '
                'remain linked to the correct person.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileSelectionHint extends StatelessWidget {
  const _ProfileSelectionHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.monitor_heart_outlined,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: 12),
            const Expanded(
              child: Text(
                'Choose the profile you want to use. You can also add '
                'a new profile from this screen.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
