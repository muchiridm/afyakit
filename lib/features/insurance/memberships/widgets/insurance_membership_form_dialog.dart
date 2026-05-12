// lib/features/insurance/memberships/widgets/insurance_membership_form_dialog.dart

import 'package:afyakit/features/insurance/memberships/models/insurance_membership.dart';
import 'package:flutter/material.dart';

class InsuranceMembershipFormDialog extends StatefulWidget {
  const InsuranceMembershipFormDialog({
    super.key,
    this.initial,
    required this.patientId,
    this.patientDisplayName,
    this.payerContactId,
    this.payerDisplayName,
  });

  final InsuranceMembership? initial;

  final String patientId;
  final String? patientDisplayName;

  final String? payerContactId;
  final String? payerDisplayName;

  @override
  State<InsuranceMembershipFormDialog> createState() =>
      _InsuranceMembershipFormDialogState();
}

class _InsuranceMembershipFormDialogState
    extends State<InsuranceMembershipFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _payerContactIdCtl;
  late final TextEditingController _payerDisplayNameCtl;
  late final TextEditingController _memberNumberCtl;
  late final TextEditingController _memberNameCtl;
  late final TextEditingController _principalNameCtl;
  late final TextEditingController _schemeCtl;
  late final TextEditingController _medicalCardNumberCtl;
  late final TextEditingController _policyNumberCtl;
  late final TextEditingController _providerCodeCtl;
  late final TextEditingController _providerNameCtl;
  late final TextEditingController _effectiveFromCtl;
  late final TextEditingController _effectiveToCtl;
  late final TextEditingController _notesCtl;

  bool _isActive = true;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    final initial = widget.initial;

    _payerContactIdCtl = TextEditingController(
      text: initial?.payerContactId ?? widget.payerContactId ?? '',
    );
    _payerDisplayNameCtl = TextEditingController(
      text: initial?.payerDisplayName ?? widget.payerDisplayName ?? '',
    );
    _memberNumberCtl = TextEditingController(text: initial?.memberNumber ?? '');
    _memberNameCtl = TextEditingController(text: initial?.memberName ?? '');
    _principalNameCtl = TextEditingController(
      text: initial?.principalName ?? '',
    );
    _schemeCtl = TextEditingController(text: initial?.scheme ?? '');
    _medicalCardNumberCtl = TextEditingController(
      text: initial?.medicalCardNumber ?? '',
    );
    _policyNumberCtl = TextEditingController(text: initial?.policyNumber ?? '');
    _providerCodeCtl = TextEditingController(text: initial?.providerCode ?? '');
    _providerNameCtl = TextEditingController(text: initial?.providerName ?? '');
    _effectiveFromCtl = TextEditingController(
      text: initial?.effectiveFrom ?? '',
    );
    _effectiveToCtl = TextEditingController(text: initial?.effectiveTo ?? '');
    _notesCtl = TextEditingController(text: initial?.notes ?? '');

    _isActive = initial?.isActive ?? true;
  }

  @override
  void dispose() {
    _payerContactIdCtl.dispose();
    _payerDisplayNameCtl.dispose();
    _memberNumberCtl.dispose();
    _memberNameCtl.dispose();
    _principalNameCtl.dispose();
    _schemeCtl.dispose();
    _medicalCardNumberCtl.dispose();
    _policyNumberCtl.dispose();
    _providerCodeCtl.dispose();
    _providerNameCtl.dispose();
    _effectiveFromCtl.dispose();
    _effectiveToCtl.dispose();
    _notesCtl.dispose();

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
    bool readOnly = false,
  }) {
    return SizedBox(
      width: width,
      child: TextFormField(
        controller: controller,
        decoration: _dec(label, hint: hint, helper: helper),
        validator: validator,
        minLines: minLines,
        maxLines: maxLines,
        readOnly: readOnly,
      ),
    );
  }

  Widget _summary(BuildContext context) {
    final patientLabel = [
      widget.patientDisplayName,
      widget.patientId,
    ].whereType<String>().where((v) => v.trim().isNotEmpty).join(' · ');

    return SizedBox(
      width: 720,
      child: Material(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'Patient: ${patientLabel.isEmpty ? widget.patientId : patientLabel}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      ),
    );
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final input = InsuranceMembershipUpsertInput(
      patientId: widget.patientId,
      payerContactId: _payerContactIdCtl.text.trim(),
      payerDisplayName: _nullable(_payerDisplayNameCtl),
      memberNumber: _memberNumberCtl.text.trim(),
      memberName: _nullable(_memberNameCtl),
      principalName: _nullable(_principalNameCtl),
      scheme: _nullable(_schemeCtl),
      medicalCardNumber: _nullable(_medicalCardNumberCtl),
      policyNumber: _nullable(_policyNumberCtl),
      providerCode: _nullable(_providerCodeCtl),
      providerName: _nullable(_providerNameCtl),
      effectiveFrom: _nullable(_effectiveFromCtl),
      effectiveTo: _nullable(_effectiveToCtl),
      notes: _nullable(_notesCtl),
      isActive: _isActive,
    );

    Navigator.of(context).pop(input);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        _isEdit ? 'Edit insurance membership' : 'Add insurance membership',
      ),
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
                _summary(context),
                _field(
                  width: 340,
                  controller: _payerContactIdCtl,
                  label: 'Insurer / payer contact ID',
                  validator: (v) => _required(v, 'Payer contact ID'),
                ),
                _field(
                  width: 340,
                  controller: _payerDisplayNameCtl,
                  label: 'Insurer / payer name',
                  helper: 'Optional; backend can resolve this from contact ID.',
                ),
                _field(
                  width: 220,
                  controller: _memberNumberCtl,
                  label: 'Member No',
                  validator: (v) => _required(v, 'Member No'),
                ),
                _field(
                  width: 220,
                  controller: _memberNameCtl,
                  label: 'Member Name',
                ),
                _field(
                  width: 220,
                  controller: _principalNameCtl,
                  label: 'Principal Name',
                ),
                _field(width: 220, controller: _schemeCtl, label: 'Scheme'),
                _field(
                  width: 220,
                  controller: _policyNumberCtl,
                  label: 'Policy No',
                ),
                _field(
                  width: 220,
                  controller: _medicalCardNumberCtl,
                  label: 'Medical Card No',
                ),
                _field(
                  width: 220,
                  controller: _providerCodeCtl,
                  label: 'Provider Code',
                ),
                _field(
                  width: 220,
                  controller: _providerNameCtl,
                  label: 'Provider Name',
                ),
                _field(
                  width: 220,
                  controller: _effectiveFromCtl,
                  label: 'Effective From',
                  hint: 'YYYY-MM-DD',
                  validator: _date,
                ),
                _field(
                  width: 220,
                  controller: _effectiveToCtl,
                  label: 'Effective To',
                  hint: 'YYYY-MM-DD',
                  validator: _date,
                ),
                _field(
                  width: 720,
                  controller: _notesCtl,
                  label: 'Notes',
                  minLines: 2,
                  maxLines: 4,
                ),
                SizedBox(
                  width: 420,
                  child: SwitchListTile(
                    value: _isActive,
                    onChanged: (value) => setState(() => _isActive = value),
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active membership'),
                    subtitle: const Text(
                      'Only active memberships should be used for new claims.',
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
          onPressed: _submit,
          child: Text(_isEdit ? 'Save membership' : 'Create membership'),
        ),
      ],
    );
  }
}
