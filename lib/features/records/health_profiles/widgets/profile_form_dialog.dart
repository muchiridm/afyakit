// lib/features/records/health_profiles/widgets/profile_form_dialog.dart

import 'package:afyakit/features/records/health_profiles/widgets/profile_labels.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';

import 'package:flutter/material.dart';

import 'package:afyakit/features/records/health_profiles/profile_models.dart';

class ProfileFormDialog extends StatefulWidget {
  const ProfileFormDialog({
    super.key,
    this.initial,
    this.initialContact,
    this.initialRelationship,
    this.prefillFromContact = true,
    this.allowExplicitContactLink = false,
  });

  final Profile? initial;

  /// Optional Native Contact seed.
  ///
  /// Staff can select an existing Native Contact. A self relationship can
  /// optionally prefill profile name, phone and email.
  /// For dependents, this only seeds the payer/contact link unless
  /// [prefillFromContact] is true and the relationship is self.
  final NativeContact? initialContact;

  /// Optional initial relationship between the patient and selected contact.
  final ProfileContactRelationship? initialRelationship;

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
  State<ProfileFormDialog> createState() => _ProfileFormDialogState();
}

class _ProfileFormDialogState extends State<ProfileFormDialog> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _fullNameCtl;
  late final TextEditingController _dobCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _nationalIdCtl;
  late final TextEditingController _notesCtl;

  late ProfileContactRelationship _relationship;
  late ProfileGender _gender;
  late bool _isActive;

  NativeContact? _selectedContact;

  bool get _isEdit => widget.initial != null;

  @override
  void initState() {
    super.initState();

    final patient = widget.initial;

    final seedContact = widget.allowExplicitContactLink
        ? widget.initialContact
        : null;

    _selectedContact = seedContact;

    _relationship =
        widget.initialRelationship ??
        (widget.allowExplicitContactLink
            ? ProfileContactRelationship.other
            : ProfileContactRelationship.self);

    final shouldPrefillFromContact =
        seedContact != null &&
        widget.prefillFromContact &&
        _relationship == ProfileContactRelationship.self;

    final seedName = shouldPrefillFromContact
        ? _contactDisplayName(seedContact)
        : '';
    final seedPhone = shouldPrefillFromContact
        ? _contactPhone(seedContact)
        : '';
    final seedEmail = shouldPrefillFromContact
        ? _contactEmail(seedContact)
        : '';

    _fullNameCtl = TextEditingController(
      text: _firstNonEmpty([patient?.fullName, seedName]),
    );

    _dobCtl = TextEditingController(text: patient?.dob ?? '');

    _phoneCtl = TextEditingController(
      text: _firstNonEmpty([patient?.phone, seedPhone]),
    );

    _emailCtl = TextEditingController(
      text: _firstNonEmpty([patient?.email, seedEmail]),
    );

    _nationalIdCtl = TextEditingController(text: patient?.nationalId ?? '');
    _notesCtl = TextEditingController(text: patient?.notes ?? '');

    _gender = patient?.gender ?? ProfileGender.unknown;
    _isActive = patient?.isActive ?? true;
  }

  @override
  void dispose() {
    _fullNameCtl.dispose();
    _dobCtl.dispose();
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

  static String _contactDisplayName(NativeContact? contact) {
    if (contact == null) return '';

    final displayName = contact.displayName.trim();
    if (displayName.isNotEmpty) return displayName;

    return '';
  }

  static String _contactPhone(NativeContact? contact) {
    if (contact == null) return '';
    final phone = (contact.phone ?? '').trim();
    if (phone.isNotEmpty) return phone;
    return (contact.mobile ?? contact.verifiedPhone ?? '').trim();
  }

  static String _contactEmail(NativeContact? contact) {
    if (contact == null) return '';
    return (contact.email ?? contact.verifiedEmail ?? '').trim();
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

  String _genderLabel(ProfileGender value) {
    switch (value) {
      case ProfileGender.male:
        return 'Male';
      case ProfileGender.female:
        return 'Female';
      case ProfileGender.other:
        return 'Other';
      case ProfileGender.unknown:
        return 'Unknown';
    }
  }

  void _prefillMissingPatientFieldsFromContact(
    NativeContact contact, {
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

  void _submit() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final input = ProfileUpsertInput(
      fullName: _fullNameCtl.text.trim(),
      dob: _dobCtl.text.trim(),
      gender: _gender,
      accountNumber: null,
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

  Widget _relationshipField({String? helper}) {
    return SizedBox(
      width: 260,
      child: DropdownButtonFormField<ProfileContactRelationship>(
        initialValue: _relationship,
        isExpanded: true,
        decoration: _dec(
          'Relationship',
          helper:
              helper ??
              (widget.allowExplicitContactLink
                  ? 'Used when an explicit contact association is added.'
                  : 'Used when auto-linking this profile to your own account.'),
        ),
        items: ProfilesLabels.staffLinkRelationships
            .map(
              (value) => DropdownMenuItem<ProfileContactRelationship>(
                value: value,
                child: Text(
                  ProfilesLabels.relationship(value),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(growable: false),
        selectedItemBuilder: (context) {
          return ProfilesLabels.staffLinkRelationships
              .map(
                (value) => Text(
                  ProfilesLabels.relationship(value),
                  overflow: TextOverflow.ellipsis,
                ),
              )
              .toList(growable: false);
        },
        onChanged: (value) {
          if (value == null) return;

          setState(() {
            _relationship = value;

            if (value == ProfileContactRelationship.self &&
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
      title: Text(_isEdit ? 'Edit health profile' : 'New health profile'),
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
                if (widget.initial?.profileId.trim().isNotEmpty == true)
                  SizedBox(
                    width: 330,
                    child: InputDecorator(
                      decoration: _dec('Health profile ID'),
                      child: SelectableText(widget.initial!.profileId),
                    ),
                  ),
                SizedBox(
                  width: 330,
                  child: TextFormField(
                    controller: _fullNameCtl,
                    decoration: _dec('Profile name'),
                    validator: (v) => _required(v, 'Profile name'),
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
                  child: DropdownButtonFormField<ProfileGender>(
                    initialValue: _gender,
                    isExpanded: true,
                    decoration: _dec('Gender'),
                    items: ProfileGender.values
                        .map(
                          (value) => DropdownMenuItem<ProfileGender>(
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
                    keyboardType: TextInputType.phone,
                    textInputAction: TextInputAction.next,
                    decoration: _dec(
                      'Mobile (optional)',
                      hint: '+254712345678',
                      helper:
                          'Use +254 followed by 9 digits starting with 7 or 1.',
                    ),
                    validator: (value) {
                      final mobile = (value ?? '').trim();
                      if (mobile.isEmpty) return null;
                      if (!RegExp(r'^\+254[17]\d{8}$').hasMatch(mobile)) {
                        return 'Use +254 followed by 9 digits starting with 7 or 1';
                      }
                      return null;
                    },
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
                if (!widget.allowExplicitContactLink && !_isEdit)
                  _relationshipField(),

                // Contact associations are created in the Linked Payers panel.
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
                      'Inactive profiles are hidden from normal active profile lists.',
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
