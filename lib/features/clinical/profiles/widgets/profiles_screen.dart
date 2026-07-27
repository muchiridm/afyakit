// lib/features/clinical/profiles/widgets/profiles_screen.dart

import 'package:afyakit/features/clinical/profiles/controllers/profiles_controller.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profile_form_dialog.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profile_payer_link_dialog.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profiles_screen_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/profiles/models/profile_link_request_models.dart';
import 'package:afyakit/features/clinical/profiles/models/profile_models.dart';
import 'package:afyakit/features/clinical/profiles/widgets/profile_details_screen.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class ProfilesScreen extends ConsumerStatefulWidget {
  const ProfilesScreen({
    super.key,
    this.contactId,
    this.allowExplicitContactLink = false,
    this.selectionMode = false,
    this.selectionTitle,
    this.createOnOpen = false,
  });

  /// When provided, the screen is restricted to profiles linked to
  /// this contact.
  ///
  /// Member flows should always provide this value.
  final String? contactId;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  /// When true, tapping a patient returns that [Profile] through
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
  late final TextEditingController _contactIdCtl;

  ProfileContactRelationship? _relationship;
  bool _createFlowOpened = false;

  double get _maxWidth => AppLayout.contentMaxWidth;

  String? get _contactScope {
    final id = widget.contactId?.trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return id;
  }

  ProfilesScope get _scope {
    return ProfilesScope(
      contactId: _contactScope,
      allowExplicitContactLink: widget.allowExplicitContactLink,
    );
  }

  bool get _isContactScoped => _contactScope != null;

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
    _contactIdCtl = TextEditingController(text: _contactScope ?? '');

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final controller = _controller;

      await controller.load();

      if (!mounted) return;

      if (widget.createOnOpen) {
        await _openCreateDialogOnce();
      }

      if (!mounted) return;

      if (widget.allowExplicitContactLink && !widget.selectionMode) {
        await controller.loadLinkRequests(
          status: ProfileLinkRequestStatus.pendingStaffApproval,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant ProfilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldContactId = oldWidget.contactId?.trim();
    final newContactId = widget.contactId?.trim();

    if (oldContactId == newContactId &&
        oldWidget.allowExplicitContactLink == widget.allowExplicitContactLink &&
        oldWidget.selectionMode == widget.selectionMode &&
        oldWidget.createOnOpen == widget.createOnOpen) {
      return;
    }

    _contactIdCtl.text = _contactScope ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

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
    _contactIdCtl.dispose();

    super.dispose();
  }

  void _handleProfileTap(Profile patient) {
    if (widget.selectionMode) {
      Navigator.of(context).pop(patient);
      return;
    }

    _openProfileDetails(patient);
  }

  void _openProfileDetails(Profile patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => ProfileDetailsScreen(
          profile: patient,
          contactId: _contactScope,
          allowExplicitContactLink: widget.allowExplicitContactLink,
        ),
      ),
    );
  }

  Future<void> _openCreateDialogOnce() async {
    if (_createFlowOpened || !mounted) return;

    _createFlowOpened = true;
    await _openCreateDialog();
  }

  Future<void> _openCreateDialog() async {
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
        contactId: input.contactId,
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
      _contactIdCtl.clear();
    } else {
      _contactIdCtl.text = _contactScope ?? '';
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
        Padding(
          padding: const EdgeInsets.only(right: 12),
          child: FilledButton.icon(
            onPressed: state.isSaving ? null : _openCreateDialog,
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
                  contactIdController: _contactIdCtl,
                  relationship: _relationship,
                  isActive: state.isActive,
                  allowExplicitContactLink:
                      widget.allowExplicitContactLink && !widget.selectionMode,
                  onSearchSubmitted: (value) {
                    controller.applyFilters(search: value);
                  },
                  onContactIdSubmitted: (value) {
                    if (!widget.allowExplicitContactLink ||
                        widget.selectionMode) {
                      return;
                    }

                    controller.applyFilters(contactId: value);
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
                else
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Column(
                      children: state.items
                          .map(
                            (patient) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: _ProfileListTile(
                                patient: patient,
                                selectionMode: widget.selectionMode,
                                onTap: () {
                                  _handleProfileTap(patient);
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
                'Create a separate profile for yourself and each dependant. '
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

class _ProfileListTile extends StatelessWidget {
  const _ProfileListTile({
    required this.patient,
    required this.selectionMode,
    required this.onTap,
  });

  final Profile patient;
  final bool selectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final subtitleParts = <String>[];

    if (patient.relationship != null) {
      subtitleParts.add(ProfilesLabels.relationship(patient.relationship!));
    }

    final age = _patientAge(patient.dob);

    if (age != null) {
      subtitleParts.add('$age years');
    }

    final dob = _formatDob(patient.dob);

    if (dob != null) {
      subtitleParts.add('DOB $dob');
    }

    final contactName = (patient.contactDisplayName ?? '').trim();

    if (contactName.isNotEmpty) {
      subtitleParts.add(contactName);
    }

    final phone = (patient.phone ?? '').trim();

    if (phone.isNotEmpty) {
      subtitleParts.add(phone);
    }

    if (!patient.isActive) {
      subtitleParts.add('Inactive');
    }

    return Card(
      margin: EdgeInsets.zero,
      child: ListTile(
        onTap: onTap,
        leading: CircleAvatar(child: Text(_initials(patient.fullName))),
        title: Text(
          patient.fullName,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        subtitle: Text(
          subtitleParts.isEmpty ? patient.profileId : subtitleParts.join(' • '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: Icon(
          selectionMode
              ? Icons.check_circle_outline
              : Icons.chevron_right_rounded,
          color: selectionMode ? scheme.primary : scheme.onSurfaceVariant,
        ),
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

    if (parts.length == 1) {
      return parts.first[0].toUpperCase();
    }

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}

int? _patientAge(String? rawDob) {
  final dob = _parseDob(rawDob);

  if (dob == null) return null;

  final today = DateTime.now();

  var age = today.year - dob.year;

  final birthdayPassed =
      today.month > dob.month ||
      (today.month == dob.month && today.day >= dob.day);

  if (!birthdayPassed) {
    age--;
  }

  return age >= 0 ? age : null;
}

String? _formatDob(String? rawDob) {
  final dob = _parseDob(rawDob);

  if (dob == null) return null;

  final day = dob.day.toString().padLeft(2, '0');
  final month = dob.month.toString().padLeft(2, '0');

  return '$day/$month/${dob.year}';
}

DateTime? _parseDob(String? rawDob) {
  final value = rawDob?.trim();

  if (value == null || value.isEmpty) {
    return null;
  }

  return DateTime.tryParse(value);
}
