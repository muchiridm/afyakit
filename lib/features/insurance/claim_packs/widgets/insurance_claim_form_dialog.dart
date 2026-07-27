// lib/features/insurance/claim_packs/widgets/insurance_claim_form_dialog.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/controllers/prescriptions_controller.dart';
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/clinical/prescriptions/providers/prescriptions_providers.dart';
import 'package:afyakit/features/clinical/prescriptions/services/prescriptions_service.dart';
import 'package:afyakit/features/clinical/prescriptions/widgets/prescription_picker.dart';
import 'package:afyakit/features/insurance/claim_packs/models/insurance_claim_pack.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:afyakit/features/insurance/memberships/widgets/insurance_membership_picker.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/widgets/invoice_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class InsuranceClaimPackFormResult {
  const InsuranceClaimPackFormResult({
    required this.patientId,
    required this.createInput,
    required this.updateInput,
  });

  final String patientId;
  final InsuranceClaimPackCreateInput createInput;
  final InsuranceClaimPackUpdateInput updateInput;
}

class InsuranceClaimFormDialog extends ConsumerStatefulWidget {
  const InsuranceClaimFormDialog({
    super.key,
    this.initial,
    required this.memberships,
    this.initialMembershipId,
    this.invoiceId,
    this.invoiceNumber,
    this.patientId,
    this.allowedPatientIds,
  });

  final InsuranceClaimPack? initial;
  final List<InsuranceMembership> memberships;
  final String? initialMembershipId;
  final String? invoiceId;
  final String? invoiceNumber;
  final String? patientId;
  final Set<String>? allowedPatientIds;

  @override
  ConsumerState<InsuranceClaimFormDialog> createState() =>
      _InsuranceClaimFormDialogState();
}

class _InsuranceClaimFormDialogState
    extends ConsumerState<InsuranceClaimFormDialog> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late final TextEditingController _invoiceIdCtl;
  late final TextEditingController _invoiceNumberCtl;
  late final TextEditingController _prescriptionNoCtl;
  late final TextEditingController _prescriberNameCtl;
  late final TextEditingController _authCodeCtl;
  late final TextEditingController _insurerClaimNoCtl;
  late final TextEditingController _visitNoCtl;
  late final TextEditingController _serviceDateCtl;
  late final TextEditingController _diagnosisCtl;
  late final TextEditingController _icd10CodeCtl;
  late final TextEditingController _notesCtl;

  InsuranceMembership? _selectedMembership;
  ZohoInvoice? _selectedInvoice;
  Prescription? _selectedPrescription;

  String? _membershipId;
  String? _prescriptionId;

  InsuranceClaimPackStatus _status = InsuranceClaimPackStatus.draft;
  bool _isActive = true;

  bool get _isEdit => widget.initial != null;

  String get _selectedPatientId {
    return (_selectedMembership?.patientId ??
            widget.initial?.patientId ??
            widget.patientId ??
            '')
        .trim();
  }

  String? get _selectedPatientNo {
    return _cleanOrNull(
      _selectedMembership?.patientNo ??
          widget.initial?.patientNo ??
          widget.patientId,
    );
  }

  bool get _hasInvoice {
    return _nullable(_invoiceIdCtl) != null ||
        _nullable(_invoiceNumberCtl) != null ||
        _selectedInvoice != null;
  }

  @override
  void initState() {
    super.initState();

    final InsuranceClaimPack? initial = widget.initial;

    _invoiceIdCtl = TextEditingController(
      text: initial?.invoiceId ?? widget.invoiceId ?? '',
    );

    _invoiceNumberCtl = TextEditingController(
      text: initial?.invoiceNumber ?? widget.invoiceNumber ?? '',
    );

    _prescriptionNoCtl = TextEditingController(
      text: initial?.prescriptionNo ?? '',
    );

    _prescriberNameCtl = TextEditingController(
      text: initial?.prescriberName ?? '',
    );

    _authCodeCtl = TextEditingController(text: initial?.authCode ?? '');

    _insurerClaimNoCtl = TextEditingController(
      text: initial?.insurerClaimNo ?? '',
    );

    _visitNoCtl = TextEditingController(text: initial?.visitNo ?? '');
    _serviceDateCtl = TextEditingController(text: initial?.serviceDate ?? '');
    _diagnosisCtl = TextEditingController(text: initial?.diagnosis ?? '');
    _icd10CodeCtl = TextEditingController(text: initial?.icd10Code ?? '');
    _notesCtl = TextEditingController(text: initial?.notes ?? '');

    _status = initial?.status ?? InsuranceClaimPackStatus.draft;
    _isActive = initial?.isActive ?? true;

    _membershipId = _cleanOrNull(
      initial?.membershipId ?? widget.initialMembershipId,
    );

    _selectedMembership = _findMembership(_membershipId);
    _prescriptionId = _cleanOrNull(initial?.prescriptionId);

    Future<void>.microtask(_loadPrescriptions);
  }

  @override
  void dispose() {
    _invoiceIdCtl.dispose();
    _invoiceNumberCtl.dispose();
    _prescriptionNoCtl.dispose();
    _prescriberNameCtl.dispose();
    _authCodeCtl.dispose();
    _insurerClaimNoCtl.dispose();
    _visitNoCtl.dispose();
    _serviceDateCtl.dispose();
    _diagnosisCtl.dispose();
    _icd10CodeCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  Future<void> _pickMembership() async {
    final InsuranceMembership? picked = await showDialog<InsuranceMembership>(
      context: context,
      builder: (_) => InsuranceMembershipPickerDialog(
        initialMembershipId: _membershipId,
        patientId: widget.patientId ?? widget.initial?.patientId,
        allowedPatientIds: widget.allowedPatientIds,
        title: 'Select insurance membership',
        emptyText: 'No active insurance memberships found.',
      ),
    );

    if (!mounted || picked == null) return;

    final String previousPatientId = _selectedPatientId;
    final String nextPatientId = picked.patientId.trim();

    setState(() {
      _selectedMembership = picked;
      _membershipId = picked.membershipId;

      if (previousPatientId.isNotEmpty && previousPatientId != nextPatientId) {
        _clearInvoice();
        _clearPrescription();
      }
    });

    await _loadPrescriptions();
  }

  Future<void> _pickInvoice() async {
    final String patientId = _selectedPatientId;

    if (patientId.isEmpty) {
      _snack('Select a membership first.');
      return;
    }

    final ZohoInvoice? picked = await showDialog<ZohoInvoice>(
      context: context,
      builder: (_) => InvoicePickerDialog(
        initialInvoiceId: _nullable(_invoiceIdCtl),
        patientId: patientId,
        patientNo: _selectedPatientNo,

        // Do not pass patientNo as accountNumber.
        // accountNumber is a Zoho customer/member scope filter, not a patient filter.
        accountNumber: null,

        title: 'Select patient invoice',
        emptyText: 'No invoices found for this profile.',
      ),
    );

    if (!mounted || picked == null) return;

    _setInvoice(picked);
  }

  void _setInvoice(ZohoInvoice invoice) {
    setState(() {
      _selectedInvoice = invoice;
      _invoiceIdCtl.text = invoice.invoiceId;
      _invoiceNumberCtl.text = invoice.invoiceNumber ?? '';
    });
  }

  void _clearInvoice() {
    _selectedInvoice = null;
    _invoiceIdCtl.clear();
    _invoiceNumberCtl.clear();
  }

  void _clearPrescription() {
    _selectedPrescription = null;
    _prescriptionId = null;
    _prescriptionNoCtl.clear();
    _prescriberNameCtl.clear();
  }

  Future<void> _loadPrescriptions() {
    final String patientId = _selectedPatientId;

    if (patientId.isEmpty) return Future<void>.value();

    return ref
        .read(prescriptionsControllerProvider(patientId).notifier)
        .load(profileId: patientId, isActive: true);
  }

  Future<void> _uploadPrescription() async {
    final String patientId = _selectedPatientId;

    if (patientId.isEmpty) {
      _snack('Select a membership first.');
      return;
    }

    final _PrescriptionUploadMeta? meta =
        await showDialog<_PrescriptionUploadMeta>(
          context: context,
          builder: (_) => const _PrescriptionUploadMetaDialog(),
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

    final PrescriptionsController controller = ref.read(
      prescriptionsControllerProvider(patientId).notifier,
    );

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

    final PrescriptionsState state = ref.read(
      prescriptionsControllerProvider(patientId),
    );

    if (state.error != null) {
      _snack(state.error!);
      return;
    }

    final Prescription? saved = state.items.isEmpty ? null : state.items.first;

    setState(() {
      _selectedPrescription = saved;
      _prescriptionId = saved?.prescriptionId ?? _prescriptionId;
    });

    _snack('Prescription uploaded.');
  }

  void _setPrescription(Prescription? prescription) {
    setState(() {
      _selectedPrescription = prescription;
      _prescriptionId = prescription?.prescriptionId;

      if (prescription != null) {
        final String fileName = prescription.fileName.trim();

        if (_prescriptionNoCtl.text.trim().isEmpty) {
          _prescriptionNoCtl.text = fileName.isEmpty
              ? prescription.prescriptionId
              : fileName;
        }
      }
    });
  }

  void _submit() {
    final bool valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final String membershipId = (_membershipId ?? '').trim();
    final String patientId = _selectedPatientId;

    if (membershipId.isEmpty) {
      _snack('Select an insurance membership.');
      return;
    }

    if (patientId.isEmpty) {
      _snack('Selected membership has no patient ID.');
      return;
    }

    final InsuranceClaimPackCreateInput createInput =
        InsuranceClaimPackCreateInput(
          membershipId: membershipId,
          invoiceId: _nullable(_invoiceIdCtl),
          invoiceNumber: _nullable(_invoiceNumberCtl),
          prescriptionId: _cleanOrNull(_prescriptionId),
          prescriptionNo: _nullable(_prescriptionNoCtl),
          prescriberName: _nullable(_prescriberNameCtl),
          authCode: _nullable(_authCodeCtl),
          insurerClaimNo: _nullable(_insurerClaimNoCtl),
          visitNo: _nullable(_visitNoCtl),
          serviceDate: _nullable(_serviceDateCtl),
          diagnosis: _nullable(_diagnosisCtl),
          icd10Code: _nullable(_icd10CodeCtl),
          notes: _nullable(_notesCtl),
          status: _status,
          isActive: _isActive,
        );

    final InsuranceClaimPackUpdateInput updateInput =
        InsuranceClaimPackUpdateInput(
          membershipId: membershipId,
          invoiceId: _nullable(_invoiceIdCtl),
          invoiceNumber: _nullable(_invoiceNumberCtl),
          prescriptionId: _cleanOrNull(_prescriptionId),
          prescriptionNo: _nullable(_prescriptionNoCtl),
          prescriberName: _nullable(_prescriberNameCtl),
          authCode: _nullable(_authCodeCtl),
          insurerClaimNo: _nullable(_insurerClaimNoCtl),
          visitNo: _nullable(_visitNoCtl),
          serviceDate: _nullable(_serviceDateCtl),
          diagnosis: _nullable(_diagnosisCtl),
          icd10Code: _nullable(_icd10CodeCtl),
          notes: _nullable(_notesCtl),
          status: _status,
          isActive: _isActive,
        );

    Navigator.of(context).pop(
      InsuranceClaimPackFormResult(
        patientId: patientId,
        createInput: createInput,
        updateInput: updateInput,
      ),
    );
  }

  InsuranceMembership? _findMembership(String? membershipId) {
    final String id = (membershipId ?? '').trim();
    if (id.isEmpty) return null;

    for (final InsuranceMembership membership in widget.memberships) {
      if (membership.membershipId == id) return membership;
    }

    return null;
  }

  String _membershipTitle() {
    final InsuranceMembership? membership = _selectedMembership;
    if (membership != null) return membership.displayTitle;

    final String? id = _cleanOrNull(_membershipId);
    return id ?? 'No membership selected';
  }

  String _membershipSubtitle() {
    final InsuranceMembership? membership = _selectedMembership;

    if (membership == null) {
      return 'Select the patient insurance membership.';
    }

    final List<String> parts = <String>[
      membership.payerLabel,
      if ((membership.scheme ?? '').trim().isNotEmpty)
        membership.scheme!.trim(),
      if (membership.memberNo.trim().isNotEmpty)
        'Member ${membership.memberNo.trim()}',
      if ((membership.policyNo ?? '').trim().isNotEmpty)
        'Policy ${membership.policyNo!.trim()}',
      if ((membership.medicalCardNo ?? '').trim().isNotEmpty)
        'Card ${membership.medicalCardNo!.trim()}',
    ];

    return parts.where((String part) => part.trim().isNotEmpty).join(' · ');
  }

  String _invoiceTitle() {
    final ZohoInvoice? invoice = _selectedInvoice;

    if (invoice != null) {
      return invoice.invoiceNumber ?? invoice.invoiceId;
    }

    final String? invoiceNumber = _nullable(_invoiceNumberCtl);
    if (invoiceNumber != null) return invoiceNumber;

    final String? invoiceId = _nullable(_invoiceIdCtl);
    if (invoiceId != null) return invoiceId;

    return 'No invoice selected';
  }

  String _invoiceSubtitle() {
    final ZohoInvoice? invoice = _selectedInvoice;

    if (invoice == null) {
      final String? invoiceNumber = _nullable(_invoiceNumberCtl);
      final String? invoiceId = _nullable(_invoiceIdCtl);

      if (invoiceNumber != null || invoiceId != null) {
        return 'Linked invoice saved on this claim pack.';
      }

      return 'Tap to select the patient invoice for this claim pack.';
    }

    final List<String> parts = <String>[
      invoice.customerName,
      invoice.status,
      if (invoice.date != null) _formatDate(invoice.date!),
      '${invoice.currencyCode ?? ''} ${invoice.total}'.trim(),
      if (invoice.balance != null) 'Balance ${invoice.balance}',
      if (invoice.hasClaimPack) 'Claim pack linked',
      if (invoice.isInsurancePayment) 'Insurance',
    ];

    return parts.where((String p) => p.trim().isNotEmpty).join(' · ');
  }

  String _formatDate(DateTime value) {
    final DateTime local = value.toLocal();

    String two(int v) => v.toString().padLeft(2, '0');

    return '${local.year}-${two(local.month)}-${two(local.day)}';
  }

  String? _date(String? value) {
    final String trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final bool ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed);
    if (!ok) return 'Use YYYY-MM-DD';

    return null;
  }

  String? _nullable(TextEditingController controller) {
    final String value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String? _cleanOrNull(String? value) {
    final String clean = (value ?? '').trim();
    return clean.isEmpty ? null : clean;
  }

  InputDecoration _dec(String label, {String? hint, String? helper}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      helperText: helper,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  Widget _field({
    required double width,
    required TextEditingController controller,
    required String label,
    String? hint,
    String? helper,
    String? Function(String?)? validator,
    int minLines = 1,
    int maxLines = 1,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: _dec(label, hint: hint, helper: helper),
        validator: validator,
        minLines: minLines,
        maxLines: maxLines,
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final bool hasMembership =
        (_membershipId ?? '').trim().isNotEmpty || _selectedMembership != null;

    final String patientId = _selectedPatientId;

    final PrescriptionsState prescriptionState = patientId.isEmpty
        ? const PrescriptionsState()
        : ref.watch(prescriptionsControllerProvider(patientId));

    return AlertDialog(
      title: Text(_isEdit ? 'Edit claim pack' : 'Create claim pack'),
      content: SizedBox(
        width: 780,
        height: MediaQuery.of(context).size.height * 0.82,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 14, right: 8, bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 14,
              children: <Widget>[
                SizedBox(
                  width: 720,
                  child: _SelectorTile(
                    icon: Icons.health_and_safety_outlined,
                    selectedIcon: Icons.health_and_safety,
                    title: _membershipTitle(),
                    subtitle: _membershipSubtitle(),
                    hasSelection: hasMembership,
                    onTap: _pickMembership,
                  ),
                ),
                SizedBox(
                  width: 720,
                  child: _SelectorTile(
                    icon: Icons.receipt_long_outlined,
                    selectedIcon: Icons.receipt_long,
                    title: _invoiceTitle(),
                    subtitle: _invoiceSubtitle(),
                    hasSelection: _hasInvoice,
                    onTap: _pickInvoice,
                  ),
                ),
                SizedBox(
                  width: 720,
                  child: PrescriptionPickerCard(
                    patientId: patientId,
                    prescriptions: prescriptionState.items,
                    selectedPrescriptionId:
                        _selectedPrescription?.prescriptionId ??
                        _prescriptionId,
                    busy: prescriptionState.busy,
                    error: prescriptionState.error,
                    requiredForClaim: true,
                    onRefresh: patientId.isEmpty ? null : _loadPrescriptions,
                    onUpload: patientId.isEmpty ? null : _uploadPrescription,
                    onChanged: _setPrescription,
                  ),
                ),
                _field(
                  width: 340,
                  controller: _invoiceIdCtl,
                  label: 'Invoice ID',
                ),
                _field(
                  width: 340,
                  controller: _invoiceNumberCtl,
                  label: 'Invoice Number',
                ),
                _field(
                  width: 220,
                  controller: _prescriptionNoCtl,
                  label: 'Prescription No',
                ),
                _field(
                  width: 240,
                  controller: _prescriberNameCtl,
                  label: 'Prescriber Name',
                ),
                const SizedBox(width: 720, child: Divider()),
                _field(
                  width: 220,
                  controller: _authCodeCtl,
                  label: 'Auth Code',
                ),
                _field(
                  width: 220,
                  controller: _insurerClaimNoCtl,
                  label: 'Insurer Claim No',
                ),
                _field(width: 220, controller: _visitNoCtl, label: 'Visit No'),
                _field(
                  width: 220,
                  controller: _serviceDateCtl,
                  label: 'Service Date',
                  hint: 'YYYY-MM-DD',
                  validator: _date,
                ),
                const SizedBox(width: 720, child: Divider()),
                _field(
                  width: 340,
                  controller: _diagnosisCtl,
                  label: 'Diagnosis',
                ),
                _field(
                  width: 180,
                  controller: _icd10CodeCtl,
                  label: 'ICD-10 Code',
                ),
                _field(
                  width: 720,
                  controller: _notesCtl,
                  label: 'Notes',
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(width: 720, child: Divider()),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<InsuranceClaimPackStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: _dec('Status'),
                    items: InsuranceClaimPackStatus.values
                        .map(
                          (InsuranceClaimPackStatus status) =>
                              DropdownMenuItem<InsuranceClaimPackStatus>(
                                value: status,
                                child: Text(status.label),
                              ),
                        )
                        .toList(growable: false),
                    onChanged: (InsuranceClaimPackStatus? value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: SwitchListTile.adaptive(
                    value: _isActive,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active'),
                    subtitle: const Text('Retained for audit/history.'),
                    onChanged: (bool value) {
                      setState(() => _isActive = value);
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(_isEdit ? 'Save' : 'Create'),
        ),
      ],
    );
  }
}

class _PrescriptionUploadMeta {
  const _PrescriptionUploadMeta({this.note, this.prescribedOn});

  final String? note;
  final String? prescribedOn;
}

class _PrescriptionUploadMetaDialog extends StatefulWidget {
  const _PrescriptionUploadMetaDialog();

  @override
  State<_PrescriptionUploadMetaDialog> createState() =>
      _PrescriptionUploadMetaDialogState();
}

class _PrescriptionUploadMetaDialogState
    extends State<_PrescriptionUploadMetaDialog> {
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

class _SelectorTile extends StatelessWidget {
  const _SelectorTile({
    required this.icon,
    required this.selectedIcon,
    required this.title,
    required this.subtitle,
    required this.hasSelection,
    required this.onTap,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String title;
  final String subtitle;
  final bool hasSelection;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;

    return Material(
      color: hasSelection
          ? scheme.primaryContainer.withValues(alpha: 0.25)
          : scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: Icon(
          hasSelection ? selectedIcon : icon,
          color: hasSelection ? scheme.primary : null,
        ),
        title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      ),
    );
  }
}
