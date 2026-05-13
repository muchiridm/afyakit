// lib/features/insurance/claims/widgets/insurance_claim_form_dialog.dart

import 'package:afyakit/features/insurance/claims/models/insurance_claim.dart';
import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:flutter/material.dart';

class InsuranceClaimFormDialog extends StatefulWidget {
  const InsuranceClaimFormDialog({
    super.key,
    this.initial,
    required this.invoiceId,
    this.invoiceNumber,
    required this.memberships,
    this.initialMembershipId,
  });

  final InsuranceClaim? initial;

  final String invoiceId;
  final String? invoiceNumber;

  final List<InsuranceMembership> memberships;
  final String? initialMembershipId;

  @override
  State<InsuranceClaimFormDialog> createState() =>
      _InsuranceClaimFormDialogState();
}

class _InsuranceClaimFormDialogState extends State<InsuranceClaimFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _authCodeCtl;
  late final TextEditingController _claimNoCtl;
  late final TextEditingController _visitNoCtl;
  late final TextEditingController _serviceDateCtl;
  late final TextEditingController _prescriptionNoCtl;
  late final TextEditingController _prescriberNameCtl;
  late final TextEditingController _diagnosisCtl;
  late final TextEditingController _icd10CodeCtl;
  late final TextEditingController _investigationsCtl;
  late final TextEditingController _treatmentRecommendationsCtl;
  late final TextEditingController _notesCtl;

  late ClaimFormStatus _claimFormStatus;
  late EtimsStatus _etimsStatus;

  late final TextEditingController _claimFormUrlCtl;
  late final TextEditingController _invoicePdfUrlCtl;
  late final TextEditingController _etimsNoCtl;
  late final TextEditingController _etimsUrlCtl;

  String? _membershipId;
  InsuranceClaimStatus _status = InsuranceClaimStatus.draft;
  bool _isActive = true;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _authCodeCtl = TextEditingController(text: initial?.authCode ?? '');
    _claimNoCtl = TextEditingController(text: initial?.claimNo ?? '');
    _visitNoCtl = TextEditingController(text: initial?.visitNo ?? '');
    _serviceDateCtl = TextEditingController(text: initial?.serviceDate ?? '');
    _prescriptionNoCtl = TextEditingController(
      text: initial?.prescriptionNo ?? '',
    );
    _prescriberNameCtl = TextEditingController(
      text: initial?.prescriberName ?? '',
    );
    _diagnosisCtl = TextEditingController(text: initial?.diagnosis ?? '');
    _icd10CodeCtl = TextEditingController(text: initial?.icd10Code ?? '');
    _investigationsCtl = TextEditingController(
      text: initial?.investigations ?? '',
    );
    _treatmentRecommendationsCtl = TextEditingController(
      text: initial?.treatmentRecommendations ?? '',
    );
    _notesCtl = TextEditingController(text: initial?.notes ?? '');

    _claimFormStatus = initial?.claimFormStatus ?? ClaimFormStatus.pending;
    _etimsStatus = initial?.etimsStatus ?? EtimsStatus.pending;

    _claimFormUrlCtl = TextEditingController(text: initial?.claimFormUrl ?? '');
    _invoicePdfUrlCtl = TextEditingController(
      text: initial?.invoicePdfUrl ?? '',
    );
    _etimsNoCtl = TextEditingController(text: initial?.etimsNo ?? '');
    _etimsUrlCtl = TextEditingController(text: initial?.etimsUrl ?? '');

    _status = initial?.status ?? InsuranceClaimStatus.draft;
    _isActive = initial?.isActive ?? true;

    final requestedMembershipId =
        initial?.membershipId ?? widget.initialMembershipId;

    final exists = widget.memberships.any(
      (item) => item.membershipId == requestedMembershipId,
    );

    _membershipId = exists ? requestedMembershipId : null;
  }

  @override
  void dispose() {
    _authCodeCtl.dispose();
    _claimNoCtl.dispose();
    _visitNoCtl.dispose();
    _serviceDateCtl.dispose();
    _prescriptionNoCtl.dispose();
    _prescriberNameCtl.dispose();
    _diagnosisCtl.dispose();
    _icd10CodeCtl.dispose();
    _investigationsCtl.dispose();
    _treatmentRecommendationsCtl.dispose();
    _notesCtl.dispose();

    _claimFormUrlCtl.dispose();
    _invoicePdfUrlCtl.dispose();
    _etimsNoCtl.dispose();
    _etimsUrlCtl.dispose();

    super.dispose();
  }

  String? _required(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$label is required';
    return null;
  }

  String? _date(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;

    final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed);
    if (!ok) return 'Use YYYY-MM-DD';

    return null;
  }

  String? _nullable(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
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

  String _membershipLabel(InsuranceMembership membership) {
    final patient = membership.patientDisplayName?.trim() ?? '';
    final payer = membership.payerDisplayName?.trim() ?? '';
    final memberNo = membership.memberNo.trim();
    final scheme = membership.scheme?.trim() ?? '';

    final parts = <String>[
      if (patient.isNotEmpty) patient,
      if (payer.isNotEmpty) payer,
      if (memberNo.isNotEmpty) memberNo,
      if (scheme.isNotEmpty) scheme,
    ];

    return parts.isEmpty ? membership.membershipId : parts.join(' · ');
  }

  Widget _invoiceSummary(BuildContext context) {
    final invoice = [
      widget.invoiceNumber,
      widget.invoiceId,
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' · ');

    return SizedBox(
      width: 720,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Invoice: ${invoice.isEmpty ? widget.invoiceId : invoice}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final membershipId = _membershipId?.trim() ?? '';
    if (membershipId.isEmpty) return;

    final input = InsuranceClaimUpsertInput(
      membershipId: membershipId,
      invoiceId: widget.invoiceId,
      invoiceNumber: widget.invoiceNumber,
      authCode: _nullable(_authCodeCtl),
      claimNo: _nullable(_claimNoCtl),
      visitNo: _nullable(_visitNoCtl),
      serviceDate: _nullable(_serviceDateCtl),
      prescriptionNo: _nullable(_prescriptionNoCtl),
      prescriberName: _nullable(_prescriberNameCtl),
      diagnosis: _nullable(_diagnosisCtl),
      icd10Code: _nullable(_icd10CodeCtl),
      investigations: _nullable(_investigationsCtl),
      treatmentRecommendations: _nullable(_treatmentRecommendationsCtl),
      notes: _nullable(_notesCtl),
      claimFormStatus: _claimFormStatus,
      claimFormUrl: _nullable(_claimFormUrlCtl),
      invoicePdfUrl: _nullable(_invoicePdfUrlCtl),
      etimsStatus: _etimsStatus,
      etimsNo: _nullable(_etimsNoCtl),
      etimsUrl: _nullable(_etimsUrlCtl),
      status: _status,
      isActive: _isActive,
    );

    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    final hasMemberships = widget.memberships.isNotEmpty;

    return AlertDialog(
      title: Text(_isEdit ? 'Edit insurance claim' : 'Create insurance claim'),
      content: SizedBox(
        width: 760,
        height: MediaQuery.of(context).size.height * 0.74,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 14, right: 8, bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 14,
              children: [
                _invoiceSummary(context),
                SizedBox(
                  width: 720,
                  child: DropdownButtonFormField<String>(
                    initialValue: _membershipId,
                    isExpanded: true,
                    decoration: _dec(
                      'Insurance Membership',
                      helper:
                          'Select the verified membership. Patient/member details come from this record.',
                    ),
                    items: widget.memberships
                        .map(
                          (membership) => DropdownMenuItem<String>(
                            value: membership.membershipId,
                            child: Text(
                              _membershipLabel(membership),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        )
                        .toList(growable: false),
                    validator: (value) {
                      if (!hasMemberships) {
                        return 'No active insurance memberships found';
                      }
                      return _required(value, 'Insurance membership');
                    },
                    onChanged: hasMemberships
                        ? (value) => setState(() => _membershipId = value)
                        : null,
                  ),
                ),
                _field(
                  width: 220,
                  controller: _authCodeCtl,
                  label: 'Auth Code',
                ),
                _field(width: 220, controller: _claimNoCtl, label: 'Claim No'),
                _field(width: 220, controller: _visitNoCtl, label: 'Visit No'),
                _field(
                  width: 220,
                  controller: _serviceDateCtl,
                  label: 'Service Date',
                  hint: 'YYYY-MM-DD',
                  validator: _date,
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
                  controller: _investigationsCtl,
                  label: 'Investigations',
                  minLines: 2,
                  maxLines: 4,
                ),
                _field(
                  width: 720,
                  controller: _treatmentRecommendationsCtl,
                  label: 'Treatment recommendations',
                  minLines: 2,
                  maxLines: 4,
                ),
                const SizedBox(width: 720, child: Divider()),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<ClaimFormStatus>(
                    initialValue: _claimFormStatus,
                    isExpanded: true,
                    decoration: _dec('Claim Form'),
                    items: ClaimFormStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _claimFormStatus = value);
                    },
                  ),
                ),
                _field(
                  width: 480,
                  controller: _claimFormUrlCtl,
                  label: 'Claim Form URL',
                ),
                _field(
                  width: 480,
                  controller: _invoicePdfUrlCtl,
                  label: 'Invoice PDF URL',
                ),
                SizedBox(
                  width: 220,
                  child: DropdownButtonFormField<EtimsStatus>(
                    initialValue: _etimsStatus,
                    isExpanded: true,
                    decoration: _dec('eTIMS Status'),
                    items: EtimsStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _etimsStatus = value);
                    },
                  ),
                ),
                _field(width: 220, controller: _etimsNoCtl, label: 'eTIMS No'),
                _field(
                  width: 480,
                  controller: _etimsUrlCtl,
                  label: 'eTIMS URL',
                ),
                const SizedBox(width: 720, child: Divider()),
                _field(
                  width: 720,
                  controller: _notesCtl,
                  label: 'Notes',
                  minLines: 2,
                  maxLines: 4,
                ),
                SizedBox(
                  width: 260,
                  child: DropdownButtonFormField<InsuranceClaimStatus>(
                    initialValue: _status,
                    isExpanded: true,
                    decoration: _dec('Claim Status'),
                    items: InsuranceClaimStatus.values
                        .map(
                          (status) => DropdownMenuItem(
                            value: status,
                            child: Text(status.label),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _status = value);
                    },
                  ),
                ),
                SizedBox(
                  width: 420,
                  child: SwitchListTile(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active claim'),
                    subtitle: const Text(
                      'Inactive claims are retained for audit/history.',
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: hasMemberships ? _submit : null,
          child: Text(_isEdit ? 'Save claim' : 'Create claim'),
        ),
      ],
    );
  }
}
