// lib/features/clinical/patients/widgets/patient_profiles_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/patients/models/patient_link_request_models.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_details_screen.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_payer_link_dialog.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart';

import 'package:afyakit/shared/layout/app_layout.dart';
import 'package:afyakit/shared/layout/app_page.dart';

class PatientProfilesScreen extends ConsumerStatefulWidget {
  const PatientProfilesScreen({
    super.key,
    this.contactId,
    this.allowExplicitContactLink = false,
    this.selectionMode = false,
    this.selectionTitle,
  });

  /// When provided, the screen is restricted to patient profiles linked to
  /// this contact.
  ///
  /// Member flows should always provide this value.
  final String? contactId;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  /// When true, tapping a patient returns that [PatientProfile] through
  /// [Navigator.pop] instead of opening [PatientDetailsScreen].
  final bool selectionMode;

  /// Optional title shown while selecting a patient profile.
  final String? selectionTitle;

  @override
  ConsumerState<PatientProfilesScreen> createState() {
    return _PatientProfilesScreenState();
  }
}

class _PatientProfilesScreenState extends ConsumerState<PatientProfilesScreen> {
  late final TextEditingController _searchCtl;
  late final TextEditingController _contactIdCtl;

  PatientContactRelationship? _relationship;

  double get _maxWidth => AppLayout.contentMaxWidth;

  String? get _contactScope {
    final id = widget.contactId?.trim();

    if (id == null || id.isEmpty) {
      return null;
    }

    return id;
  }

  PatientProfilesScope get _scope {
    return PatientProfilesScope(
      contactId: _contactScope,
      allowExplicitContactLink: widget.allowExplicitContactLink,
    );
  }

  bool get _isContactScoped => _contactScope != null;

  PatientProfilesController get _controller {
    return ref.read(patientProfilesControllerProvider(_scope).notifier);
  }

  PatientProfilesState get _currentState {
    return ref.read(patientProfilesControllerProvider(_scope));
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

      if (widget.allowExplicitContactLink && !widget.selectionMode) {
        await controller.loadLinkRequests(
          status: PatientLinkRequestStatus.pendingStaffApproval,
        );
      }
    });
  }

  @override
  void didUpdateWidget(covariant PatientProfilesScreen oldWidget) {
    super.didUpdateWidget(oldWidget);

    final oldContactId = oldWidget.contactId?.trim();
    final newContactId = widget.contactId?.trim();

    if (oldContactId == newContactId &&
        oldWidget.allowExplicitContactLink == widget.allowExplicitContactLink &&
        oldWidget.selectionMode == widget.selectionMode) {
      return;
    }

    _contactIdCtl.text = _contactScope ?? '';

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      _controller.refreshAll();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _contactIdCtl.dispose();

    super.dispose();
  }

  void _handlePatientTap(PatientProfile patient) {
    if (widget.selectionMode) {
      Navigator.of(context).pop(patient);
      return;
    }

    _openPatientDetails(patient);
  }

  void _openPatientDetails(PatientProfile patient) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PatientDetailsScreen(
          patient: patient,
          contactId: _contactScope,
          allowExplicitContactLink: widget.allowExplicitContactLink,
        ),
      ),
    );
  }

  Future<void> _openCreateDialog() async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) => PatientProfileFormDialog(
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      await _controller.create(input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile created')));
    } catch (_) {
      if (!mounted) return;

      _showErrorFromState();
    }
  }

  Future<void> _openApproveLinkRequestDialog(PatientLinkRequest request) async {
    if (!widget.allowExplicitContactLink || widget.selectionMode) {
      return;
    }

    final input = await PatientPayerLinkDialog.showApprove(
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

  Future<void> _openRejectLinkRequestDialog(PatientLinkRequest request) async {
    if (!widget.allowExplicitContactLink || widget.selectionMode) {
      return;
    }

    final input = await PatientPayerLinkDialog.showReject(context: context);

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

  void _clearFilters(PatientProfilesController controller) {
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

      return 'Select patient profile';
    }

    return widget.allowExplicitContactLink
        ? 'Patient profiles'
        : 'My patient profiles';
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;

    final state = ref.watch(patientProfilesControllerProvider(scope));

    final controller = ref.read(
      patientProfilesControllerProvider(scope).notifier,
    );

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
        if (!widget.selectionMode)
          Padding(
            padding: const EdgeInsets.only(right: 12),
            child: FilledButton.icon(
              onPressed: state.isSaving ? null : _openCreateDialog,
              icon: const Icon(Icons.add),
              label: const Text('Add patient'),
            ),
          ),
      ],
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                if (!widget.selectionMode)
                  PatientLinkRequestsPanel(
                    state: state,
                    allowExplicitContactLink: widget.allowExplicitContactLink,
                    onRefresh: () {
                      controller.loadLinkRequests(
                        status: widget.allowExplicitContactLink
                            ? PatientLinkRequestStatus.pendingStaffApproval
                            : null,
                        resetStatus: !widget.allowExplicitContactLink,
                      );
                    },
                    onApprove: _openApproveLinkRequestDialog,
                    onReject: _openRejectLinkRequestDialog,
                  ),
                if (widget.selectionMode) const _PatientSelectionHint(),
                PatientProfilesFilterBar(
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
                  PatientProfilesErrorBanner(error: state.error!),
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
                            ? 'No linked patient profiles found'
                            : 'No patient profiles found',
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
                              child: _PatientProfileListTile(
                                patient: patient,
                                selectionMode: widget.selectionMode,
                                onTap: () {
                                  _handlePatientTap(patient);
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

class _PatientSelectionHint extends StatelessWidget {
  const _PatientSelectionHint();

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
                'Choose the person whose health measurements '
                'you want to record or review.',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PatientProfileListTile extends StatelessWidget {
  const _PatientProfileListTile({
    required this.patient,
    required this.selectionMode,
    required this.onTap,
  });

  final PatientProfile patient;
  final bool selectionMode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    final subtitleParts = <String>[];

    if (patient.relationship != null) {
      subtitleParts.add(
        PatientProfilesLabels.relationship(patient.relationship!),
      );
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
          subtitleParts.isEmpty ? patient.patientId : subtitleParts.join(' • '),
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
