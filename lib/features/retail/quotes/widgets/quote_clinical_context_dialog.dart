// lib/features/retail/quotes/widgets/quote_clinical_context_dialog.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_controller.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_picker.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescription_picker.dart';
import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/claims/widgets/insurance_claim_picker.dart';
import 'package:afyakit/features/insurance/memberships/controllers/insurance_memberships_controller.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_picker.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteClinicalContextSelection {
  const QuoteClinicalContextSelection({
    required this.patientSnapshot,
    required this.paymentContext,
    this.membershipId,
    this.payerContact,
    this.prescription,
    this.prescriptionId,
    this.claim,
  });

  final SalesDocumentPatientSnapshot patientSnapshot;
  final QuotePaymentContext paymentContext;
  final String? membershipId;
  final ZohoContact? payerContact;
  final Prescription? prescription;

  /// Fallback when the dialog has an initial prescription ID but the full
  /// Prescription object has not hydrated yet.
  final String? prescriptionId;

  /// Optional existing claim selected for workflow continuity.
  ///
  /// For now, this is returned by the dialog but does not automatically persist
  /// to the quote unless QuoteMetaController/QuoteDraft are later extended to
  /// store claim_id.
  final InsuranceClaim? claim;

  bool get isInsurance => paymentContext == QuotePaymentContext.insurance;
}

class QuoteClinicalContextDialog extends ConsumerStatefulWidget {
  const QuoteClinicalContextDialog({
    super.key,
    this.initialPatientId,
    this.initialMembershipId,
    this.initialPrescriptionId,
    this.initialClaimId,
    this.initialPaymentContext = QuotePaymentContext.directPay,
  });

  final String? initialPatientId;
  final String? initialMembershipId;
  final String? initialPrescriptionId;
  final String? initialClaimId;
  final QuotePaymentContext initialPaymentContext;

  @override
  ConsumerState<QuoteClinicalContextDialog> createState() =>
      _QuoteClinicalContextDialogState();
}

class _QuoteClinicalContextDialogState
    extends ConsumerState<QuoteClinicalContextDialog> {
  static const String _missingMemberContactId = '__missing_member_contact__';

  PatientProfile? _patient;
  InsuranceMembership? _membership;
  Prescription? _prescription;
  InsuranceClaim? _claim;

  bool _initialHydrationAttempted = false;

  late QuotePaymentContext _paymentContext;

  QuoteContactPolicy get _policy => ref.read(quoteContactPolicyProvider);

  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;

  String get _memberContactId {
    return (ref.read(zohoMemberCustomerScopeProvider)?.contactId ?? '').trim();
  }

  String? get _patientId {
    final String id = (_patient?.patientId ?? widget.initialPatientId ?? '')
        .trim();

    return id.isEmpty ? null : id;
  }

  bool get _requiresInsurance {
    return _paymentContext == QuotePaymentContext.insurance;
  }

  PatientProfilesScope get _memberPatientScope {
    final String contactId = _memberContactId;

    return PatientProfilesScope(
      contactId: contactId.isEmpty ? _missingMemberContactId : contactId,
      allowExplicitContactLink: false,
    );
  }

  @override
  void initState() {
    super.initState();

    _paymentContext = widget.initialPaymentContext;

    if (_isMemberScoped) {
      Future<void>.microtask(_loadLinkedPatientsForMembershipGuard);
    }

    final String? patientId = _patientId;
    if (patientId != null) {
      Future<void>.microtask(() => _loadPrescriptions(patientId));
    }
  }

  Future<void> _loadLinkedPatientsForMembershipGuard() async {
    final controller = ref.read(
      patientProfilesControllerProvider(_memberPatientScope).notifier,
    );

    controller.setIsActive(true);
    await controller.load();
  }

  Future<void> _loadPrescriptions(String patientId) {
    return ref
        .read(prescriptionsControllerProvider(patientId).notifier)
        .load(patientId: patientId, isActive: true);
  }

  void _hydrateInitialSelections({
    required List<InsuranceMembership> memberships,
    required List<Prescription> prescriptions,
  }) {
    if (_initialHydrationAttempted) return;

    final String? initialPatientId = _clean(widget.initialPatientId);
    final String? initialMembershipId = _clean(widget.initialMembershipId);
    final String? initialPrescriptionId = _clean(widget.initialPrescriptionId);

    final InsuranceMembership? membership = _findMembershipById(
      memberships,
      initialMembershipId,
    );

    final Prescription? prescription = _findPrescriptionById(
      prescriptions,
      initialPrescriptionId,
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _initialHydrationAttempted) return;

      final String? resolvedPatientId =
          _clean(membership?.patientId) ?? initialPatientId;

      setState(() {
        _initialHydrationAttempted = true;

        if (_patient == null) {
          if (membership != null) {
            _patient = PatientProfile(
              patientId: membership.patientId,
              fullName:
                  _clean(membership.patientDisplayName) ?? membership.patientId,
              isActive: true,
            );
          } else if (initialPatientId != null) {
            _patient = PatientProfile(
              patientId: initialPatientId,
              fullName: initialPatientId,
              isActive: true,
            );
          }
        }

        _membership ??= membership;
        _prescription ??= prescription;
      });

      if (resolvedPatientId != null && prescriptions.isEmpty) {
        Future<void>.microtask(() => _loadPrescriptions(resolvedPatientId));
      }
    });
  }

  InsuranceMembership? _findMembershipById(
    List<InsuranceMembership> memberships,
    String? membershipId,
  ) {
    final String? id = _clean(membershipId);
    if (id == null) return null;

    for (final InsuranceMembership membership in memberships) {
      if (membership.membershipId.trim() == id) return membership;
    }

    return null;
  }

  PatientProfile? _findLoadedPatientById(String? patientId) {
    final String? id = _clean(patientId);
    if (id == null) return null;

    if (!_isMemberScoped) return null;

    final state = ref.read(
      patientProfilesControllerProvider(_memberPatientScope),
    );

    for (final PatientProfile patient in state.items) {
      if (patient.patientId.trim() == id) return patient;
    }

    return null;
  }

  Prescription? _findPrescriptionById(
    List<Prescription> prescriptions,
    String? prescriptionId,
  ) {
    final String? id = _clean(prescriptionId);
    if (id == null) return null;

    for (final Prescription prescription in prescriptions) {
      if (prescription.prescriptionId.trim() == id) return prescription;
    }

    return null;
  }

  Set<String>? _allowedPatientIdsForMemberships() {
    if (!_isMemberScoped) return null;

    final state = ref.watch(
      patientProfilesControllerProvider(_memberPatientScope),
    );

    return state.items
        .where((PatientProfile p) => p.isActive)
        .map((PatientProfile p) => p.patientId.trim())
        .where((String id) => id.isNotEmpty)
        .toSet();
  }

  double _membershipPickerHeight(int count) {
    if (count <= 0) return 220;
    if (count == 1) return 250;
    if (count == 2) return 320;

    return 420;
  }

  double _claimPickerHeight({
    required bool hasMembership,
    required int membershipCount,
  }) {
    if (!hasMembership) return 220;

    if (membershipCount <= 1) return 240;

    return 300;
  }

  void _setPatient(PatientProfile patient) {
    setState(() {
      final String? previousPatientId = _patient?.patientId.trim();
      final String nextPatientId = patient.patientId.trim();

      _patient = patient;

      if (previousPatientId != null &&
          previousPatientId.isNotEmpty &&
          previousPatientId != nextPatientId) {
        _membership = null;
        _prescription = null;
        _claim = null;
      }
    });

    _loadPrescriptions(patient.patientId);
  }

  void _setMembership(InsuranceMembership membership) {
    final PatientProfile? loadedPatient = _findLoadedPatientById(
      membership.patientId,
    );

    setState(() {
      _paymentContext = QuotePaymentContext.insurance;
      _membership = membership;
      _claim = null;

      _patient ??=
          loadedPatient ??
          PatientProfile(
            patientId: membership.patientId,
            fullName:
                _clean(membership.patientDisplayName) ?? membership.patientId,
            isActive: true,
          );
    });

    _loadPrescriptions(membership.patientId);
  }

  void _setPrescription(Prescription? prescription) {
    setState(() => _prescription = prescription);
  }

  void _setClaim(InsuranceClaim claim) {
    setState(() => _claim = claim);
  }

  Future<void> _uploadPrescription() async {
    final String? patientId = _patientId;

    if (patientId == null) {
      _snack('Pick a patient first.');
      return;
    }

    final _PrescriptionUploadMeta? meta =
        await showDialog<_PrescriptionUploadMeta>(
          context: context,
          builder: (_) => const _PrescriptionMetaDialog(),
        );

    if (!mounted || meta == null) return;

    final FilePickerResult? picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      withData: true,
      type: FileType.custom,
      allowedExtensions: const <String>['jpg', 'jpeg', 'png', 'webp', 'pdf'],
    );

    if (!mounted || picked == null || picked.files.isEmpty) return;

    final PlatformFile file = picked.files.single;
    final bytes = file.bytes;

    if (bytes == null || bytes.isEmpty) {
      _snack('Could not read selected file.');
      return;
    }

    final String tenantId = ref.read(tenantIdProvider).trim();
    final provider = prescriptionsControllerProvider(patientId);
    final PrescriptionsController controller = ref.read(provider.notifier);

    await controller.upload(
      tenantId: tenantId,
      patientId: patientId,
      file: PickedPrescriptionFile(
        fileName: file.name,
        extension: file.extension ?? 'jpg',
        bytes: bytes,
      ),
      note: meta.note,
      prescribedOn: meta.prescribedOn,
    );

    if (!mounted) return;

    final PrescriptionsState rxState = ref.read(provider);

    if (rxState.error != null) {
      _snack(rxState.error!);
      return;
    }

    final Prescription? saved = rxState.items.isEmpty
        ? null
        : rxState.items.first;

    setState(() {
      _prescription = saved;
    });

    _snack('Prescription uploaded.');
  }

  void _useContext() {
    final PatientProfile? patient = _patient;
    final InsuranceMembership? membership = _membership;
    final Prescription? prescription = _prescription;

    final String? initialPatientId = _clean(widget.initialPatientId);
    final String? initialMembershipId = _clean(widget.initialMembershipId);
    final String? initialPrescriptionId = _clean(widget.initialPrescriptionId);

    final String? resolvedPatientId =
        _clean(patient?.patientId) ??
        _clean(membership?.patientId) ??
        initialPatientId;

    final String? resolvedMembershipId =
        _clean(membership?.membershipId) ?? initialMembershipId;

    final String? resolvedPrescriptionId =
        _clean(prescription?.prescriptionId) ?? initialPrescriptionId;

    if (resolvedPatientId == null) {
      _snack('Pick a patient first.');
      return;
    }

    if (_requiresInsurance && resolvedMembershipId == null) {
      _snack('Pick an insurance membership.');
      return;
    }

    if (_requiresInsurance && resolvedPrescriptionId == null) {
      _snack('Pick or upload a prescription.');
      return;
    }

    final PatientProfile resolvedPatient =
        patient ??
        _findLoadedPatientById(resolvedPatientId) ??
        PatientProfile(
          patientId: resolvedPatientId,
          fullName: _clean(membership?.patientDisplayName) ?? resolvedPatientId,
          isActive: true,
        );

    final SalesDocumentPatientSnapshot patientSnapshot =
        _requiresInsurance && membership != null
        ? _snapshotFromMembership(membership, patient: resolvedPatient)
        : _snapshotFromPatient(resolvedPatient);

    final ZohoContact? payerContact = _requiresInsurance && membership != null
        ? _payerContactFromMembership(membership)
        : null;

    Navigator.of(context).pop(
      QuoteClinicalContextSelection(
        patientSnapshot: patientSnapshot,
        paymentContext: _paymentContext,
        membershipId: _requiresInsurance ? resolvedMembershipId : null,
        payerContact: payerContact,
        prescription: prescription,
        prescriptionId: resolvedPrescriptionId,
        claim: _requiresInsurance ? _claim : null,
      ),
    );
  }

  SalesDocumentPatientSnapshot _snapshotFromPatient(PatientProfile patient) {
    return SalesDocumentPatientSnapshot(
      patientId: patient.patientId,
      patientNo: patient.patientId,
      fullName: patient.fullName,
      dob: patient.dob,
      gender: patient.gender?.name,
      relationship: patient.relationship?.name,
    );
  }

  SalesDocumentPatientSnapshot _snapshotFromMembership(
    InsuranceMembership membership, {
    PatientProfile? patient,
  }) {
    final String patientId = membership.patientId.trim();

    final String patientName =
        _clean(patient?.fullName) ??
        _clean(membership.patientDisplayName) ??
        patientId;

    final String payerName =
        _clean(membership.payerDisplayName) ?? membership.payerContactId;

    return SalesDocumentPatientSnapshot(
      patientId: patientId,
      patientNo: _clean(membership.patientNo) ?? patientId,
      fullName: patientName,
      dob: patient?.dob,
      gender: patient?.gender?.name,
      relationship: patient?.relationship?.name,
      membershipId: membership.membershipId,
      memberNo: membership.memberNo,
      scheme: membership.scheme,
      payerName: payerName,
    );
  }

  ZohoContact _payerContactFromMembership(InsuranceMembership membership) {
    final String payerName =
        _clean(membership.payerDisplayName) ?? membership.payerContactId;

    return ZohoContact(
      contactId: membership.payerContactId.trim(),
      displayName: payerName,
      accountNumber: _clean(membership.payerAccountNumber),
      contactType: 'customer',
      isInsurancePayer: true,
    );
  }

  String? _clean(String? value) {
    final String s = (value ?? '').trim();
    return s.isEmpty ? null : s;
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final String? patientId = _patientId;

    final PrescriptionsState rxState = patientId == null
        ? const PrescriptionsState()
        : ref.watch(prescriptionsControllerProvider(patientId));

    final Set<String>? allowedPatientIds = _allowedPatientIdsForMemberships();

    final InsuranceMembershipsState membershipsState = ref.watch(
      insuranceMembershipsControllerProvider,
    );

    _hydrateInitialSelections(
      memberships: membershipsState.items,
      prescriptions: rxState.items,
    );

    final int visibleMembershipCount = membershipsState.visibleActiveCount(
      patientId: patientId,
      allowedPatientIds: allowedPatientIds,
    );

    final double membershipPickerHeight = _membershipPickerHeight(
      visibleMembershipCount,
    );

    final double claimPickerHeight = _claimPickerHeight(
      hasMembership: _membership != null,
      membershipCount: visibleMembershipCount,
    );

    final bool memberContactMissing =
        _isMemberScoped && _memberContactId.isEmpty;

    return AlertDialog(
      title: const Text('Clinical context'),
      content: SizedBox(
        width: 820,
        height: MediaQuery.of(context).size.height * 0.82,
        child: Column(
          children: <Widget>[
            if (memberContactMissing)
              const Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: _ErrorText(
                  'Your customer profile is not linked yet. Please refresh or contact support.',
                ),
              ),
            Expanded(
              child: ListView(
                children: <Widget>[
                  _SectionTitle(
                    icon: Icons.person_outline,
                    title: 'Patient',
                    subtitle: _isMemberScoped
                        ? 'Choose from your linked patient profiles.'
                        : 'Choose the patient receiving care or medicine.',
                  ),
                  PatientPickerCard(
                    selectedPatient: _patient,
                    busy: false,
                    contactId: _isMemberScoped ? _memberContactId : null,
                    forcePickerMode: !_isMemberScoped,
                    onChanged: _setPatient,
                  ),
                  const SizedBox(height: 16),
                  _SectionTitle(
                    icon: Icons.payments_outlined,
                    title: 'Payment',
                    subtitle:
                        'Choose whether this is direct-pay or insurance billing.',
                  ),
                  SegmentedButton<QuotePaymentContext>(
                    showSelectedIcon: false,
                    segments: const <ButtonSegment<QuotePaymentContext>>[
                      ButtonSegment<QuotePaymentContext>(
                        value: QuotePaymentContext.directPay,
                        icon: Icon(Icons.payments_outlined),
                        label: Text('Direct pay'),
                      ),
                      ButtonSegment<QuotePaymentContext>(
                        value: QuotePaymentContext.insurance,
                        icon: Icon(Icons.health_and_safety_outlined),
                        label: Text('Insurance'),
                      ),
                    ],
                    selected: <QuotePaymentContext>{_paymentContext},
                    onSelectionChanged: (Set<QuotePaymentContext> selected) {
                      setState(() {
                        _paymentContext = selected.first;

                        if (_paymentContext == QuotePaymentContext.directPay) {
                          _membership = null;
                          _claim = null;
                        }
                      });
                    },
                  ),
                  if (_requiresInsurance) ...<Widget>[
                    const SizedBox(height: 16),
                    _SectionTitle(
                      icon: Icons.health_and_safety_outlined,
                      title: 'Insurance membership',
                      subtitle: _isMemberScoped
                          ? 'Choose cover linked to your patient profiles.'
                          : 'Choose the payer/insurer membership.',
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: membershipPickerHeight,
                        child: InsuranceMembershipPickerCard(
                          initialMembershipId:
                              _membership?.membershipId ??
                              widget.initialMembershipId,
                          patientId: patientId,
                          allowedPatientIds: allowedPatientIds,
                          title: _isMemberScoped
                              ? 'Your insurance memberships'
                              : 'Insurance memberships',
                          emptyText: _isMemberScoped
                              ? 'No insurance memberships found for your linked profiles.'
                              : 'No active insurance memberships found.',
                          onSelected: _setMembership,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _SectionTitle(
                      icon: Icons.assignment_outlined,
                      title: 'Existing claim',
                      subtitle: _membership == null
                          ? 'Pick a membership first to check existing claims.'
                          : 'Optional. Select an existing claim if this quote belongs to an open claim workflow.',
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 180),
                      curve: Curves.easeOut,
                      alignment: Alignment.topCenter,
                      child: SizedBox(
                        height: claimPickerHeight,
                        child: InsuranceClaimPickerCard(
                          initialClaimId:
                              _claim?.claimId ?? widget.initialClaimId,
                          patientId: patientId,
                          membershipId: _membership?.membershipId,
                          allowedPatientIds: allowedPatientIds,
                          title: 'Existing claims',
                          emptyText: _membership == null
                              ? 'Pick an insurance membership first.'
                              : 'No active claim found for this patient/member.',
                          onSelected: _setClaim,
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  _SectionTitle(
                    icon: Icons.description_outlined,
                    title: 'Prescription',
                    subtitle: _requiresInsurance
                        ? 'Pick or upload a prescription for claim support.'
                        : 'Optional for direct-pay clinical quotes.',
                  ),
                  PrescriptionPickerCard(
                    patientId: patientId,
                    prescriptions: rxState.items,
                    selectedPrescriptionId:
                        _prescription?.prescriptionId ??
                        widget.initialPrescriptionId,
                    busy: rxState.busy,
                    error: rxState.error,
                    requiredForClaim: _requiresInsurance,
                    onRefresh: patientId == null
                        ? null
                        : () => _loadPrescriptions(patientId),
                    onUpload: patientId == null ? null : _uploadPrescription,
                    onChanged: _setPrescription,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton.icon(
          onPressed: () => Navigator.of(context).pop(null),
          icon: const Icon(Icons.close),
          label: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: _useContext,
          icon: const Icon(Icons.check),
          label: const Text('Use context'),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Icon(icon, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PrescriptionUploadMeta {
  const _PrescriptionUploadMeta({this.note, this.prescribedOn});

  final String? note;
  final String? prescribedOn;
}

class _PrescriptionMetaDialog extends StatefulWidget {
  const _PrescriptionMetaDialog();

  @override
  State<_PrescriptionMetaDialog> createState() =>
      _PrescriptionMetaDialogState();
}

class _PrescriptionMetaDialogState extends State<_PrescriptionMetaDialog> {
  final TextEditingController _noteController = TextEditingController();
  final TextEditingController _prescribedOnController = TextEditingController();

  @override
  void dispose() {
    _noteController.dispose();
    _prescribedOnController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Prescription details'),
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: _prescribedOnController,
              decoration: const InputDecoration(
                labelText: 'Prescribed on',
                hintText: 'YYYY-MM-DD',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Note',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton.icon(
          onPressed: () {
            final String? prescribedOn = _clean(_prescribedOnController.text);

            if (prescribedOn != null &&
                !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(prescribedOn)) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Date must be YYYY-MM-DD')),
              );
              return;
            }

            Navigator.pop(
              context,
              _PrescriptionUploadMeta(
                note: _clean(_noteController.text),
                prescribedOn: prescribedOn,
              ),
            );
          },
          icon: const Icon(Icons.check),
          label: const Text('Continue'),
        ),
      ],
    );
  }

  String? _clean(String value) {
    final String s = value.trim();
    return s.isEmpty ? null : s;
  }
}

class _ErrorText extends StatelessWidget {
  const _ErrorText(this.message);

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(
      message,
      style: TextStyle(color: Theme.of(context).colorScheme.error),
    );
  }
}
