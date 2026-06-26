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
  });

  /// When provided, this screen is hard-scoped to patients linked to this contact.
  ///
  /// Member mode must pass this so members never see all tenant patient profiles.
  final String? contactId;

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  @override
  ConsumerState<PatientProfilesScreen> createState() =>
      _PatientProfilesScreenState();
}

class _PatientProfilesScreenState extends ConsumerState<PatientProfilesScreen> {
  late final TextEditingController _searchCtl;
  late final TextEditingController _contactIdCtl;

  PatientContactRelationship? _relationship;

  double get _maxWidth => AppLayout.contentMaxWidth;

  String? get _contactScope {
    final id = widget.contactId?.trim();
    if (id == null || id.isEmpty) return null;
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

      if (widget.allowExplicitContactLink) {
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
        oldWidget.allowExplicitContactLink == widget.allowExplicitContactLink) {
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
    if (!widget.allowExplicitContactLink) return;

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
    if (!widget.allowExplicitContactLink) return;

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
    if (error == null || error.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  void _clearFilters(PatientProfilesController controller) {
    _searchCtl.clear();

    if (widget.allowExplicitContactLink && !_isContactScoped) {
      _contactIdCtl.clear();
    } else {
      _contactIdCtl.text = _contactScope ?? '';
    }

    setState(() => _relationship = null);
    controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final scope = _scope;
    final state = ref.watch(patientProfilesControllerProvider(scope));
    final controller = ref.read(
      patientProfilesControllerProvider(scope).notifier,
    );

    final title = widget.allowExplicitContactLink
        ? 'Patient profiles'
        : 'My patient profiles';

    return AppPage(
      title: title,
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
                PatientProfilesFilterBar(
                  searchController: _searchCtl,
                  contactIdController: _contactIdCtl,
                  relationship: _relationship,
                  isActive: state.isActive,
                  allowExplicitContactLink: widget.allowExplicitContactLink,
                  onSearchSubmitted: (value) {
                    controller.applyFilters(search: value);
                  },
                  onContactIdSubmitted: (value) {
                    if (!widget.allowExplicitContactLink) return;
                    controller.applyFilters(contactId: value);
                  },
                  onRelationshipChanged: (value) {
                    setState(() => _relationship = value);
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
                  onClearFilters: () => _clearFilters(controller),
                ),
                if (state.error != null && state.error!.trim().isNotEmpty)
                  PatientProfilesErrorBanner(error: state.error!),
                if (state.isLoading)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else if (state.items.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(32),
                    child: Center(child: Text('No patient profiles found')),
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
                                onTap: () => _openPatientDetails(patient),
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

class _PatientProfileListTile extends StatelessWidget {
  const _PatientProfileListTile({required this.patient, required this.onTap});

  final PatientProfile patient;
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
          Icons.chevron_right_rounded,
          color: scheme.onSurfaceVariant,
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
    if (parts.length == 1) return parts.first[0].toUpperCase();

    return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
  }
}
