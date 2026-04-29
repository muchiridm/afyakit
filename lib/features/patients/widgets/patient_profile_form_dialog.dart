// lib/features/patients/widgets/patient_profile_form_dialog.dart

import 'package:afyakit/features/patients/models/patient_profile.dart';
import 'package:flutter/material.dart';

class PatientProfileFormDialog extends StatefulWidget {
  const PatientProfileFormDialog({super.key, this.initial});

  final PatientProfile? initial;

  @override
  State<PatientProfileFormDialog> createState() =>
      _PatientProfileFormDialogState();
}

class _PatientProfileFormDialogState extends State<PatientProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtl;
  late final TextEditingController _dobCtl;
  late final TextEditingController _memberNumberCtl;
  late final TextEditingController _insuranceCtl;
  late final TextEditingController _schemeCtl;
  late final TextEditingController _payerContactIdCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _nationalIdCtl;
  late final TextEditingController _policyNumberCtl;
  late final TextEditingController _principalMemberNameCtl;
  late final TextEditingController _relationshipCtl;
  late final TextEditingController _authorizationNumberCtl;
  late final TextEditingController _notesCtl;

  late bool _isActive;

  @override
  void initState() {
    super.initState();

    final p = widget.initial;

    _fullNameCtl = TextEditingController(text: p?.fullName ?? '');
    _dobCtl = TextEditingController(text: p?.dob ?? '');
    _memberNumberCtl = TextEditingController(text: p?.memberNumber ?? '');
    _insuranceCtl = TextEditingController(text: p?.insurance ?? '');
    _schemeCtl = TextEditingController(text: p?.scheme ?? '');
    _payerContactIdCtl = TextEditingController(text: p?.payerContactId ?? '');
    _phoneCtl = TextEditingController(text: p?.phone ?? '');
    _emailCtl = TextEditingController(text: p?.email ?? '');
    _nationalIdCtl = TextEditingController(text: p?.nationalId ?? '');
    _policyNumberCtl = TextEditingController(text: p?.policyNumber ?? '');
    _principalMemberNameCtl = TextEditingController(
      text: p?.principalMemberName ?? '',
    );
    _relationshipCtl = TextEditingController(
      text: p?.relationshipToPrincipal ?? '',
    );
    _authorizationNumberCtl = TextEditingController(
      text: p?.authorizationNumber ?? '',
    );
    _notesCtl = TextEditingController(text: p?.notes ?? '');
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _dobCtl.dispose();
    _memberNumberCtl.dispose();
    _insuranceCtl.dispose();
    _schemeCtl.dispose();
    _payerContactIdCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _nationalIdCtl.dispose();
    _policyNumberCtl.dispose();
    _principalMemberNameCtl.dispose();
    _relationshipCtl.dispose();
    _authorizationNumberCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '$label is required';
    return null;
  }

  String? _dateValidator(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return 'DOB is required';

    final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed);
    if (!ok) return 'Use YYYY-MM-DD';

    return null;
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final input = PatientProfileUpsertInput(
      fullName: _fullNameCtl.text.trim(),
      dob: _dobCtl.text.trim(),
      memberNumber: _memberNumberCtl.text.trim(),
      insurance: _insuranceCtl.text.trim(),
      scheme: _schemeCtl.text.trim(),
      payerContactId: _payerContactIdCtl.text.trim(),
      phone: _phoneCtl.text.trim(),
      email: _emailCtl.text.trim(),
      nationalId: _nationalIdCtl.text.trim(),
      policyNumber: _policyNumberCtl.text.trim(),
      principalMemberName: _principalMemberNameCtl.text.trim(),
      relationshipToPrincipal: _relationshipCtl.text.trim(),
      authorizationNumber: _authorizationNumberCtl.text.trim(),
      notes: _notesCtl.text.trim(),
      isActive: _isActive,
    );

    Navigator.of(context).pop(input);
  }

  InputDecoration _dec(String label) {
    return InputDecoration(
      labelText: label,
      border: const OutlineInputBorder(),
      isDense: true,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEdit = widget.initial != null;

    return AlertDialog(
      title: Text(isEdit ? 'Edit patient profile' : 'Add patient profile'),
      content: SizedBox(
        width: 720,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Wrap(
              runSpacing: 12,
              spacing: 12,
              children: [
                SizedBox(
                  width: 330,
                  child: TextFormField(
                    controller: _fullNameCtl,
                    decoration: _dec('Patient name'),
                    validator: (v) => _required(v, 'Patient name'),
                  ),
                ),
                SizedBox(
                  width: 180,
                  child: TextFormField(
                    controller: _dobCtl,
                    decoration: _dec('DOB (YYYY-MM-DD)'),
                    validator: _dateValidator,
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _memberNumberCtl,
                    decoration: _dec('Member number'),
                    validator: (v) => _required(v, 'Member number'),
                  ),
                ),
                SizedBox(
                  width: 240,
                  child: TextFormField(
                    controller: _insuranceCtl,
                    decoration: _dec('Insurance'),
                    validator: (v) => _required(v, 'Insurance'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _schemeCtl,
                    decoration: _dec('Scheme'),
                    validator: (v) => _required(v, 'Scheme'),
                  ),
                ),
                SizedBox(
                  width: 330,
                  child: TextFormField(
                    controller: _payerContactIdCtl,
                    decoration: _dec('Payer contact ID'),
                    validator: (v) => _required(v, 'Payer contact ID'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _phoneCtl,
                    decoration: _dec('Phone'),
                  ),
                ),
                SizedBox(
                  width: 280,
                  child: TextFormField(
                    controller: _emailCtl,
                    decoration: _dec('Email'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _nationalIdCtl,
                    decoration: _dec('National ID'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _policyNumberCtl,
                    decoration: _dec('Policy number'),
                  ),
                ),
                SizedBox(
                  width: 330,
                  child: TextFormField(
                    controller: _principalMemberNameCtl,
                    decoration: _dec('Principal member name'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _relationshipCtl,
                    decoration: _dec('Relationship'),
                  ),
                ),
                SizedBox(
                  width: 220,
                  child: TextFormField(
                    controller: _authorizationNumberCtl,
                    decoration: _dec('Authorization number'),
                  ),
                ),
                SizedBox(
                  width: 672,
                  child: TextFormField(
                    controller: _notesCtl,
                    decoration: _dec('Notes'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ),
                SwitchListTile(
                  value: _isActive,
                  onChanged: (v) => setState(() => _isActive = v),
                  title: const Text('Active'),
                  contentPadding: EdgeInsets.zero,
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
          child: Text(isEdit ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}
