// lib/features/clinical/patients/widgets/patient_profile_form_dialog.dart

import 'package:afyakit/features/clinical/patients/patient_profile.dart';
import 'package:flutter/material.dart';

class PatientProfileFormDialog extends StatefulWidget {
  const PatientProfileFormDialog({
    super.key,
    this.initial,
    this.allowExplicitContactLink = false,
  });

  final PatientProfile? initial;

  /// Staff/admin only.
  /// For normal self/dependent creation, keep this false and use the
  /// separate "Link to me / my dependent" flow instead.
  final bool allowExplicitContactLink;

  @override
  State<PatientProfileFormDialog> createState() =>
      _PatientProfileFormDialogState();
}

class _PatientProfileFormDialogState extends State<PatientProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtl;
  late final TextEditingController _dobCtl;
  late final TextEditingController _contactIdCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _nationalIdCtl;
  late final TextEditingController _notesCtl;

  late ContactPatientRelationship _relationship;
  late PatientGender _gender;
  late bool _isActive;

  @override
  void initState() {
    super.initState();

    final p = widget.initial;

    _fullNameCtl = TextEditingController(text: p?.fullName ?? '');
    _dobCtl = TextEditingController(text: p?.dob ?? '');
    _contactIdCtl = TextEditingController(text: p?.contactId ?? '');
    _phoneCtl = TextEditingController(text: p?.phone ?? '');
    _emailCtl = TextEditingController(text: p?.email ?? '');
    _nationalIdCtl = TextEditingController(text: p?.nationalId ?? '');
    _notesCtl = TextEditingController(text: p?.notes ?? '');

    _relationship = p?.relationship ?? ContactPatientRelationship.self;
    _gender = p?.gender ?? PatientGender.unknown;
    _isActive = p?.isActive ?? true;
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _dobCtl.dispose();
    _contactIdCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _nationalIdCtl.dispose();
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
    if (trimmed.isEmpty) return null;

    final ok = RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(trimmed);
    if (!ok) return 'Use YYYY-MM-DD';

    return null;
  }

  String _relationshipLabel(ContactPatientRelationship value) {
    switch (value) {
      case ContactPatientRelationship.self:
        return 'Self';
      case ContactPatientRelationship.child:
        return 'Child';
      case ContactPatientRelationship.spouse:
        return 'Spouse';
      case ContactPatientRelationship.parent:
        return 'Parent';
      case ContactPatientRelationship.guardian:
        return 'Guardian';
      case ContactPatientRelationship.other:
        return 'Other';
    }
  }

  String _genderLabel(PatientGender value) {
    switch (value) {
      case PatientGender.male:
        return 'Male';
      case PatientGender.female:
        return 'Female';
      case PatientGender.other:
        return 'Other';
      case PatientGender.unknown:
        return 'Unknown';
    }
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final input = PatientProfileUpsertInput(
      fullName: _fullNameCtl.text.trim(),
      dob: _dobCtl.text.trim(),
      gender: _gender,
      contactId: widget.allowExplicitContactLink
          ? _contactIdCtl.text.trim()
          : null,
      relationship: _relationship,
      phone: _phoneCtl.text.trim(),
      email: _emailCtl.text.trim(),
      nationalId: _nationalIdCtl.text.trim(),
      notes: _notesCtl.text.trim(),
      isActive: _isActive,
    );

    Navigator.of(context).pop(input);
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
                if (widget.initial?.patientId != null &&
                    widget.initial!.patientId.trim().isNotEmpty)
                  SizedBox(
                    width: 330,
                    child: InputDecorator(
                      decoration: _dec('DawaPap patient ID'),
                      child: SelectableText(widget.initial!.patientId),
                    ),
                  ),
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
                  width: 180,
                  child: DropdownButtonFormField<PatientGender>(
                    value: _gender,
                    decoration: _dec('Gender'),
                    items: PatientGender.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_genderLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _gender = value);
                    },
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
                  child: DropdownButtonFormField<ContactPatientRelationship>(
                    value: _relationship,
                    decoration: _dec(
                      'Relationship',
                      helper: widget.allowExplicitContactLink
                          ? 'Used only if an explicit contact association is added.'
                          : 'Used for self/dependent ownership.',
                    ),
                    items: ContactPatientRelationship.values
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_relationshipLabel(value)),
                          ),
                        )
                        .toList(growable: false),
                    onChanged: (value) {
                      if (value == null) return;
                      setState(() => _relationship = value);
                    },
                  ),
                ),
                if (widget.allowExplicitContactLink)
                  SizedBox(
                    width: 452,
                    child: TextFormField(
                      controller: _contactIdCtl,
                      decoration: _dec(
                        'Associated contact ID (optional)',
                        hint: 'Staff/admin explicit contact link only',
                      ),
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
