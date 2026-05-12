// lib/features/clinical/patients/widgets/patient_profile_form_dialog.dart

import 'package:flutter/material.dart';

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profiles_screen_widgets.dart';
import 'package:afyakit/features/retail/contacts/widgets/contact_picker_dialog.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';

class PatientProfileFormDialog extends StatefulWidget {
  const PatientProfileFormDialog({
    super.key,
    this.initial,
    this.initialContact,
    this.initialRelationship,
    this.prefillFromContact = true,
    this.allowExplicitContactLink = false,
  });

  final PatientProfile? initial;

  /// Optional contact seed.
  ///
  /// Useful for staff flows where a patient is being created from an existing
  /// Zoho contact. For self-patients, this can prefill name/phone/email.
  /// For dependents, this only seeds the payer/contact link unless
  /// [prefillFromContact] is true and the relationship is self.
  final ZohoContact? initialContact;

  /// Optional initial relationship between the patient and selected contact.
  final PatientContactRelationship? initialRelationship;

  /// Whether to copy contact name/phone/email into patient fields.
  ///
  /// This only applies when the relationship is self.
  final bool prefillFromContact;

  /// Staff/admin only.
  ///
  /// When false, this form creates/edits patient demographics only.
  /// Member ownership/linking is handled by the separate self/dependent flow.
  final bool allowExplicitContactLink;

  @override
  State<PatientProfileFormDialog> createState() =>
      _PatientProfileFormDialogState();
}

class _PatientProfileFormDialogState extends State<PatientProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtl;
  late final TextEditingController _dobCtl;
  late final TextEditingController _contactLookupCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _nationalIdCtl;
  late final TextEditingController _notesCtl;

  late PatientContactRelationship _relationship;
  late PatientGender _gender;
  late bool _isActive;

  ZohoContact? _selectedContact;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    final patient = widget.initial;
    final primaryLink = patient?.primaryLinkedContact;

    final seedContact = widget.allowExplicitContactLink
        ? widget.initialContact
        : null;

    _selectedContact = seedContact;

    _relationship =
        patient?.relationship ??
        primaryLink?.relationship ??
        widget.initialRelationship ??
        PatientContactRelationship.self;

    final shouldPrefillFromContact =
        seedContact != null &&
        widget.prefillFromContact &&
        _relationship == PatientContactRelationship.self;

    final seedName = shouldPrefillFromContact
        ? _contactDisplayName(seedContact)
        : '';
    final seedPhone = shouldPrefillFromContact
        ? _contactPhone(seedContact)
        : '';
    final seedEmail = shouldPrefillFromContact
        ? _contactEmail(seedContact)
        : '';
    final seedContactId = _clean(seedContact?.contactId);

    _fullNameCtl = TextEditingController(
      text: _firstNonEmpty([patient?.fullName, seedName]),
    );

    _dobCtl = TextEditingController(text: patient?.dob ?? '');

    _contactLookupCtl = TextEditingController(
      text: _firstNonEmpty([
        patient?.contactId,
        primaryLink?.contactId,
        seedContactId,
      ]),
    );

    _phoneCtl = TextEditingController(
      text: _firstNonEmpty([patient?.phone, seedPhone]),
    );

    _emailCtl = TextEditingController(
      text: _firstNonEmpty([patient?.email, seedEmail]),
    );

    _nationalIdCtl = TextEditingController(text: patient?.nationalId ?? '');
    _notesCtl = TextEditingController(text: patient?.notes ?? '');

    _gender = patient?.gender ?? PatientGender.unknown;
    _isActive = patient?.isActive ?? true;
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _dobCtl.dispose();
    _contactLookupCtl.dispose();
    _phoneCtl.dispose();
    _emailCtl.dispose();
    _nationalIdCtl.dispose();
    _notesCtl.dispose();
    super.dispose();
  }

  static String _clean(String? value) {
    return (value ?? '').trim();
  }

  static String _firstNonEmpty(List<String?> values) {
    for (final value in values) {
      final clean = _clean(value);
      if (clean.isNotEmpty) return clean;
    }

    return '';
  }

  static String _contactDisplayName(ZohoContact? contact) {
    if (contact == null) return '';

    final displayName = contact.displayName.trim();
    if (displayName.isNotEmpty) return displayName;

    final title = contact.title.trim();
    if (title.isNotEmpty) return title;

    return '';
  }

  static String _contactPhone(ZohoContact? contact) {
    if (contact == null) return '';
    return contact.bestPhone.trim();
  }

  static String _contactEmail(ZohoContact? contact) {
    if (contact == null) return '';
    return contact.bestEmail.trim();
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

  String? _contactIdFromLookup(String value) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return null;

    final looksLikeZohoContactId = RegExp(r'^\d{8,}$').hasMatch(trimmed);
    if (!looksLikeZohoContactId) return null;

    return trimmed;
  }

  String? _effectiveContactId() {
    final selectedContactId = _selectedContact?.contactId.trim();
    if (selectedContactId != null && selectedContactId.isNotEmpty) {
      return selectedContactId;
    }

    return _contactIdFromLookup(_contactLookupCtl.text);
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

  void _prefillMissingPatientFieldsFromContact(
    ZohoContact contact, {
    bool overwrite = false,
  }) {
    final name = _contactDisplayName(contact);
    final phone = _contactPhone(contact);
    final email = _contactEmail(contact);

    if (overwrite || _fullNameCtl.text.trim().isEmpty) {
      _fullNameCtl.text = name;
    }

    if (overwrite || _phoneCtl.text.trim().isEmpty) {
      _phoneCtl.text = phone;
    }

    if (overwrite || _emailCtl.text.trim().isEmpty) {
      _emailCtl.text = email;
    }
  }

  Future<void> _pickContact() async {
    final contact = await showDialog<ZohoContact>(
      context: context,
      builder: (_) => const ContactPickerDialog(forcePickerMode: true),
    );

    if (contact == null || !mounted) return;

    setState(() {
      _selectedContact = contact;
      _contactLookupCtl.text = contact.contactId;

      if (_relationship == PatientContactRelationship.self) {
        _prefillMissingPatientFieldsFromContact(contact);
      }
    });
  }

  void _useSelectedContactAsPatient() {
    final selected = _selectedContact;
    if (selected == null) return;

    setState(() {
      _relationship = PatientContactRelationship.self;
      _prefillMissingPatientFieldsFromContact(selected, overwrite: true);
    });
  }

  void _clearSelectedContact() {
    setState(() {
      _selectedContact = null;
      _contactLookupCtl.clear();
    });
  }

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final input = PatientProfileUpsertInput(
      fullName: _fullNameCtl.text.trim(),
      dob: _dobCtl.text.trim(),
      gender: _gender,
      contactId: widget.allowExplicitContactLink ? _effectiveContactId() : null,
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

  Widget _linkedContactsPreview(PatientProfile patient) {
    if (patient.linkedContacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 672,
      child: InputDecorator(
        decoration: _dec(
          'Existing linked contacts',
          helper:
              'Existing associations are shown for review. Picking a contact creates or updates one link.',
        ),
        child: Wrap(
          spacing: 8,
          runSpacing: 8,
          children: patient.linkedContacts
              .map((link) {
                final label = [
                  link.contactDisplayName?.trim().isNotEmpty == true
                      ? link.contactDisplayName!.trim()
                      : link.contactId,
                  PatientProfilesLabels.relationship(link.relationship),
                  link.isActive ? 'active' : 'inactive',
                ].join(' · ');

                return Chip(
                  label: Text(label),
                  visualDensity: VisualDensity.compact,
                );
              })
              .toList(growable: false),
        ),
      ),
    );
  }

  Widget _selectedContactCard() {
    final selected = _selectedContact;
    final manualId = _contactIdFromLookup(_contactLookupCtl.text);

    if (selected == null && manualId == null) {
      return const SizedBox.shrink();
    }

    final title = selected?.displayName.trim().isNotEmpty == true
        ? selected!.displayName.trim()
        : 'Selected contact';

    final subtitle = selected == null
        ? manualId!
        : [
            selected.contactId,
            if ((selected.accountNumber ?? '').trim().isNotEmpty)
              selected.accountNumber!.trim(),
          ].join(' · ');

    return SizedBox(
      width: 672,
      child: Card(
        margin: EdgeInsets.zero,
        child: ListTile(
          dense: true,
          leading: const Icon(Icons.account_circle_outlined),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: Wrap(
            spacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (selected != null)
                TextButton(
                  onPressed: _useSelectedContactAsPatient,
                  child: const Text('Use as patient'),
                ),
              IconButton(
                tooltip: 'Clear payer/contact',
                onPressed: _clearSelectedContact,
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _staffContactLinkSection() {
    if (!widget.allowExplicitContactLink) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: 672,
      child: InputDecorator(
        decoration: _dec(
          'Optional payer/contact link',
          helper:
              'Staff/admin only. Pick a Zoho contact to link this patient to a payer immediately. If the contact is the patient, use relationship “Self”.',
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 320,
                  child: TextFormField(
                    controller: _contactLookupCtl,
                    decoration: const InputDecoration(
                      labelText: 'Zoho contact ID',
                      hintText: '705213400000...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                FilledButton.icon(
                  onPressed: _pickContact,
                  icon: const Icon(Icons.search),
                  label: const Text('Pick payer/contact'),
                ),
                TextButton(
                  onPressed: _clearSelectedContact,
                  child: const Text('Clear'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _relationshipField(
              helper:
                  'Relationship between this patient and the selected payer/contact.',
            ),
            const SizedBox(height: 12),
            _selectedContactCard(),
          ],
        ),
      ),
    );
  }

  Widget _relationshipField({String? helper}) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<PatientContactRelationship>(
        initialValue: _relationship,
        isExpanded: true,
        decoration: _dec(
          'Relationship',
          helper:
              helper ??
              (widget.allowExplicitContactLink
                  ? 'Used when an explicit contact association is added.'
                  : 'Used when auto-linking this patient to your own account.'),
        ),
        items: PatientProfilesLabels.staffLinkRelationships
            .map(
              (value) => DropdownMenuItem<PatientContactRelationship>(
                value: value,
                child: Text(
                  PatientProfilesLabels.relationship(value),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (context) {
          return PatientProfilesLabels.staffLinkRelationships
              .map(
                (value) => Text(
                  PatientProfilesLabels.relationship(value),
                  overflow: TextOverflow.ellipsis,
                ),
              )
              .toList(growable: false);
        },
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            _relationship = value;

            if (value == PatientContactRelationship.self &&
                _selectedContact != null) {
              _prefillMissingPatientFieldsFromContact(_selectedContact!);
            }
          });
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Edit patient profile' : 'Add patient profile'),
      content: SizedBox(
        width: 720,
        height: MediaQuery.of(context).size.height * 0.72,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.only(top: 14, right: 8, bottom: 8),
            child: Wrap(
              runSpacing: 14,
              spacing: 12,
              children: [
                if (widget.initial?.patientId.trim().isNotEmpty == true)
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
                    initialValue: _gender,
                    isExpanded: true,
                    decoration: _dec('Gender'),
                    items: PatientGender.values
                        .map(
                          (value) => DropdownMenuItem<PatientGender>(
                            value: value,
                            child: Text(
                              _genderLabel(value),
                              overflow: TextOverflow.ellipsis,
                            ),
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
                if (!widget.allowExplicitContactLink) _relationshipField(),
                _staffContactLinkSection(),
                if (widget.allowExplicitContactLink && widget.initial != null)
                  _linkedContactsPreview(widget.initial!),
                SizedBox(
                  width: 672,
                  child: TextFormField(
                    controller: _notesCtl,
                    decoration: _dec('Notes'),
                    minLines: 2,
                    maxLines: 4,
                  ),
                ),
                SizedBox(
                  width: 672,
                  child: SwitchListTile(
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                    title: const Text('Active'),
                    subtitle: const Text(
                      'Inactive profiles are hidden from normal active patient lists.',
                    ),
                    contentPadding: EdgeInsets.zero,
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
          child: Text(_isEdit ? 'Save changes' : 'Create'),
        ),
      ],
    );
  }
}
