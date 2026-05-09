import 'package:afyakit/features/clinical/patients/patient_profile.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_link_request_dialogs.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PatientProfilesScreen extends ConsumerStatefulWidget {
  const PatientProfilesScreen({
    super.key,
    this.allowExplicitContactLink = false,
  });

  /// Staff/admin mode only.
  final bool allowExplicitContactLink;

  @override
  ConsumerState<PatientProfilesScreen> createState() =>
      _PatientProfilesScreenState();
}

class _PatientProfilesScreenState extends ConsumerState<PatientProfilesScreen> {
  late final TextEditingController _searchCtl;
  late final TextEditingController _contactIdCtl;

  ContactPatientRelationship? _relationship;

  @override
  void initState() {
    super.initState();

    _searchCtl = TextEditingController();
    _contactIdCtl = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;

      final controller = ref.read(patientProfilesControllerProvider.notifier);

      if (widget.allowExplicitContactLink) {
        controller.loadLinkRequests(
          status: PatientLinkRequestStatus.pendingStaffApproval,
        );
      } else {
        controller.loadLinkRequests();
      }
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    _contactIdCtl.dispose();
    super.dispose();
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
      await ref.read(patientProfilesControllerProvider.notifier).create(input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile created')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _openEditDialog(PatientProfile patient) async {
    final input = await showDialog<PatientProfileUpsertInput>(
      context: context,
      builder: (_) => PatientProfileFormDialog(
        initial: patient,
        allowExplicitContactLink: widget.allowExplicitContactLink,
      ),
    );

    if (input == null || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .update(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile updated')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _deletePatient(PatientProfile patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete patient profile'),
        content: Text('Delete ${patient.fullName}?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .remove(patient.patientId);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Patient profile deleted')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _openLinkToSelfDialog(PatientProfile patient) async {
    final input = await PatientLinkRequestDialogs.showLinkToSelf(
      context: context,
      patient: patient,
    );

    if (input == null || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .linkToSelf(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Patient linked successfully')),
      );
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _openRequestPayerLinkDialog(PatientProfile patient) async {
    final input = await PatientLinkRequestDialogs.showRequestPayerLink(
      context: context,
      patient: patient,
    );

    if (input == null || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .requestPayerLink(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Link request submitted')));
    } catch (_) {
      if (!mounted) return;
      _showErrorFromState();
    }
  }

  Future<void> _openApproveLinkRequestDialog(PatientLinkRequest request) async {
    final input = await PatientLinkRequestDialogs.showApproveLinkRequest(
      context: context,
      request: request,
    );

    if (input == null || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .approvePayerLinkRequest(
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
    final input = await PatientLinkRequestDialogs.showRejectLinkRequest(
      context: context,
    );

    if (input == null || !mounted) return;

    try {
      await ref
          .read(patientProfilesControllerProvider.notifier)
          .rejectLinkRequest(request.requestId, input);

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
    final error = ref.read(patientProfilesControllerProvider).error;
    if (error == null || error.trim().isEmpty) return;

    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
  }

  void _clearFilters(PatientProfilesController controller) {
    _searchCtl.clear();
    _contactIdCtl.clear();
    setState(() => _relationship = null);
    controller.clearFilters();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(patientProfilesControllerProvider);
    final controller = ref.read(patientProfilesControllerProvider.notifier);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Patient profiles'),
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
      ),

      /// Important:
      /// The page body is now one scrollable area with a constrained list inside.
      /// This avoids the root Column overflow that was happening when errors,
      /// link requests, filters and cards exceeded the viewport.
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
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      children: state.items
                          .map(
                            (patient) => Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: PatientProfileCard(
                                patient: patient,
                                state: state,
                                onLinkToSelf: _openLinkToSelfDialog,
                                onRequestPayerLink: _openRequestPayerLinkDialog,
                                onEdit: _openEditDialog,
                                onDelete: _deletePatient,
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
