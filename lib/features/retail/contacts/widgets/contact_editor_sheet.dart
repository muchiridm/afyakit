// lib/features/retail/contacts/widgets/contact_editor_sheet.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/clinical/patients/models/patient_profile_models.dart';
import 'package:afyakit/features/clinical/patients/patient_profiles_service.dart';
import 'package:afyakit/features/clinical/patients/widgets/patient_profile_form_dialog.dart';

import '../zoho_contact.dart';
import 'contact_sheet_models.dart';

enum _ContactKind { person, companyOnly }

class ContactEditorSheet extends ConsumerStatefulWidget {
  const ContactEditorSheet({super.key, this.initial});

  final ZohoContact? initial;

  @override
  ConsumerState<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends ConsumerState<ContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayCtl;
  late final TextEditingController _companyCtl;
  late final TextEditingController _acctCtl;

  late final TextEditingController _personCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _mobileCtl;

  bool _editing = false;
  bool _isInsurancePayer = false;
  bool _creatingSelfPatient = false;
  bool _creatingLinkedPatient = false;
  bool _openingLinkedPatient = false;
  bool _selfPatientCreated = false;
  bool _linkedPatientCreated = false;

  late _ContactKind _kind;

  bool get _isExisting => widget.initial != null;
  bool get _readOnly => _isExisting && !_editing;

  bool get _canSave => _displayCtl.text.trim().isNotEmpty && !_readOnly;

  @override
  void initState() {
    super.initState();

    final c = widget.initial;

    _editing = c == null;
    _isInsurancePayer = c?.isInsurancePayer ?? false;

    _displayCtl = TextEditingController(text: c?.displayName ?? '');
    _companyCtl = TextEditingController(text: c?.companyName ?? '');
    _acctCtl = TextEditingController(text: c?.accountNumber ?? '');

    final pc = c?.personContact;
    _personCtl = TextEditingController(text: pc?.personName ?? '');
    _emailCtl = TextEditingController(text: pc?.email ?? '');
    _phoneCtl = TextEditingController(text: pc?.phone ?? '');
    _mobileCtl = TextEditingController(text: pc?.mobile ?? '');

    _kind = c == null
        ? _ContactKind.person
        : (pc == null ? _ContactKind.companyOnly : _ContactKind.person);

    _displayCtl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _displayCtl.dispose();
    _companyCtl.dispose();
    _acctCtl.dispose();
    _personCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _mobileCtl.dispose();
    super.dispose();
  }

  void _toggleEdit(bool v) => setState(() => _editing = v);

  void _resetFromInitial() {
    final c = widget.initial;

    _displayCtl.text = c?.displayName ?? '';
    _companyCtl.text = c?.companyName ?? '';
    _acctCtl.text = c?.accountNumber ?? '';

    final pc = c?.personContact;
    _personCtl.text = pc?.personName ?? '';
    _emailCtl.text = pc?.email ?? '';
    _phoneCtl.text = pc?.phone ?? '';
    _mobileCtl.text = pc?.mobile ?? '';

    _isInsurancePayer = c?.isInsurancePayer ?? false;
    _kind = c == null
        ? _ContactKind.person
        : (pc == null ? _ContactKind.companyOnly : _ContactKind.person);
  }

  void _setKind(_ContactKind next) {
    if (_readOnly) return;
    setState(() {
      _kind = next;
    });
  }

  void _setInsurancePayer(bool value) {
    if (_readOnly) return;

    setState(() {
      _isInsurancePayer = value;

      if (value && _kind != _ContactKind.companyOnly) {
        _kind = _ContactKind.companyOnly;
      }
    });
  }

  void _useCompanyAsDisplay() {
    if (_readOnly) return;
    final v = _companyCtl.text.trim();
    if (v.isEmpty) return;
    _displayCtl.text = v;
  }

  void _usePersonAsDisplay() {
    if (_readOnly) return;
    final v = _personCtl.text.trim();
    if (v.isEmpty) return;
    _displayCtl.text = v;
  }

  ZohoContact _buildDraft() {
    final display = _displayCtl.text.trim();
    final company = _companyCtl.text.trim();
    final account = _acctCtl.text.trim();

    final person = _personCtl.text.trim();
    final email = _emailCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final mobile = _mobileCtl.text.trim();

    PersonContact? personContact;
    if (_kind == _ContactKind.person) {
      personContact = PersonContact(
        personName: person,
        contactPersonId: widget.initial?.personContact?.contactPersonId,
        email: email.isEmpty ? null : email,
        phone: phone.isEmpty ? null : phone,
        mobile: mobile.isEmpty ? null : mobile,
        isPrimary: widget.initial?.personContact?.isPrimary,
      );
    }

    return ZohoContact(
      contactId: widget.initial?.contactId ?? '',
      displayName: display,
      companyName: company.isEmpty ? null : company,
      personContact: personContact,
      status: widget.initial?.status,
      contactType: widget.initial?.contactType,
      accountNumber: account.isEmpty ? null : account,
      isInsurancePayer: _isInsurancePayer,
      linkedPatients:
          widget.initial?.linkedPatients ?? const <ContactLinkedPatient>[],
    );
  }

  void _emitSave() {
    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;
    Navigator.of(context).pop(ContactSheetResult.saveRequested(_buildDraft()));
  }

  void _emitDelete() {
    final id = widget.initial?.contactId.trim() ?? '';
    if (id.isEmpty) return;
    Navigator.of(context).pop(ContactSheetResult.deleteRequested(id));
  }

  String _title() {
    if (!_isExisting) return 'New Contact';
    return _editing ? 'Edit Contact' : 'Contact';
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final t = Theme.of(context).textTheme;
    return Align(
      alignment: Alignment.centerLeft,
      child: Text(text, style: t.labelLarge),
    );
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
      case ContactPatientRelationship.insurance:
        return 'Insurance';
      case ContactPatientRelationship.other:
        return 'Other';
    }
  }

  bool _hasSelfPatientLink(ZohoContact contact) {
    return contact.linkedPatients.any(
      (p) => p.relationship == ContactPatientRelationship.self,
    );
  }

  bool _canOfferCreateSelfPatient(ZohoContact contact) {
    if (!_isExisting) return false;
    if (_selfPatientCreated) return false;
    if (_creatingSelfPatient) return true;

    final contactId = contact.contactId.trim();
    if (contactId.isEmpty) return false;

    if (contact.isInsurancePayer) return false;
    if (_isInsurancePayer) return false;

    if (_kind == _ContactKind.companyOnly && contact.personContact == null) {
      return false;
    }

    if (_hasSelfPatientLink(contact)) return false;

    final name = _patientNameFromContact(contact);
    return name.isNotEmpty;
  }

  String _patientNameFromContact(ZohoContact contact) {
    final title = contact.title.trim();
    if (title.isNotEmpty && title.toLowerCase() != 'contact') return title;

    final display = contact.displayName.trim();
    if (display.isNotEmpty && display.toLowerCase() != 'contact') {
      return display;
    }

    final person = contact.personContact?.personName.trim();
    if (person != null && person.isNotEmpty) return person;

    return '';
  }

  Future<void> _createSelfPatientFromContact(ZohoContact contact) async {
    if (!_canOfferCreateSelfPatient(contact)) return;

    final contactId = contact.contactId.trim();
    final name = _patientNameFromContact(contact);

    if (contactId.isEmpty || name.isEmpty) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Create self patient?'),
          content: Text(
            'Create a patient profile for $name and link it to this contact as Self?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Create'),
            ),
          ],
        );
      },
    );

    if (confirm != true || !mounted) return;

    setState(() => _creatingSelfPatient = true);

    try {
      final input = PatientProfileUpsertInput(
        fullName: name,
        dob: '',
        gender: PatientGender.unknown,
        contactId: contactId,
        relationship: PatientContactRelationship.self,
        phone: contact.bestPhone.trim(),
        email: contact.bestEmail.trim(),
        nationalId: '',
        notes: '',
        isActive: true,
      );

      await ref.read(patientProfilesServiceProvider).create(input);

      if (!mounted) return;

      setState(() {
        _creatingSelfPatient = false;
        _selfPatientCreated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Self patient profile created')),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _creatingSelfPatient = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create self patient: $e')),
      );
    }
  }

  Future<void> _addLinkedPatientForContact(
    ZohoContact contact, {
    PatientContactRelationship relationship = PatientContactRelationship.child,
  }) async {
    final contactId = contact.contactId.trim();
    if (contactId.isEmpty) return;

    setState(() => _creatingLinkedPatient = true);

    try {
      final input = await showDialog<PatientProfileUpsertInput>(
        context: context,
        builder: (_) => PatientProfileFormDialog(
          allowExplicitContactLink: true,
          initialContact: contact,
          initialRelationship: relationship,
          prefillFromContact: false,
        ),
      );

      if (input == null || !mounted) {
        if (mounted) setState(() => _creatingLinkedPatient = false);
        return;
      }

      await ref.read(patientProfilesServiceProvider).create(input);

      if (!mounted) return;

      setState(() {
        _creatingLinkedPatient = false;
        _linkedPatientCreated = true;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Linked patient created. Refresh this contact to see it.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _creatingLinkedPatient = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to create linked patient: $e')),
      );
    }
  }

  Future<void> _openLinkedPatientEditor(ContactLinkedPatient link) async {
    final patientId = link.patientId.trim();
    if (patientId.isEmpty) return;

    setState(() => _openingLinkedPatient = true);

    try {
      final service = ref.read(patientProfilesServiceProvider);
      final patient = await service.get(patientId);

      if (!mounted) return;

      setState(() => _openingLinkedPatient = false);

      final input = await showDialog<PatientProfileUpsertInput>(
        context: context,
        builder: (_) => PatientProfileFormDialog(
          initial: patient,
          allowExplicitContactLink: true,
        ),
      );

      if (input == null || !mounted) return;

      await service.update(patient.patientId, input);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Patient profile updated. Refresh this contact to see changes.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() => _openingLinkedPatient = false);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to open patient profile: $e')),
      );
    }
  }

  Widget _selfPatientActionCard(BuildContext context, ZohoContact contact) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    final hasSelf = _hasSelfPatientLink(contact);
    final canCreate = _canOfferCreateSelfPatient(contact);

    if (hasSelf) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: scheme.primaryContainer.withOpacity(0.28),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Self patient profile already linked.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (_selfPatientCreated) {
      return Container(
        width: double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: scheme.primaryContainer.withOpacity(0.28),
          border: Border.all(color: scheme.outlineVariant),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(Icons.check_circle_outline, color: scheme.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Self patient created. Refresh this contact to see the new link.',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      );
    }

    if (!canCreate) return const SizedBox.shrink();

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.personal_injury_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'No self patient profile is linked to this contact yet.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 10),
          FilledButton.icon(
            onPressed: _creatingSelfPatient
                ? null
                : () => _createSelfPatientFromContact(contact),
            icon: _creatingSelfPatient
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(_creatingSelfPatient ? 'Creating…' : 'Create self'),
          ),
        ],
      ),
    );
  }

  Widget _addLinkedPatientActionCard(
    BuildContext context,
    ZohoContact contact,
  ) {
    if (!_isExisting) return const SizedBox.shrink();

    final contactId = contact.contactId.trim();
    if (contactId.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Icon(Icons.group_add_outlined, color: scheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _linkedPatientCreated
                  ? 'Linked patient created. Refresh this contact to see it.'
                  : 'Add a dependent or another patient linked to this contact.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
          const SizedBox(width: 10),
          OutlinedButton.icon(
            onPressed: _creatingLinkedPatient
                ? null
                : () => _addLinkedPatientForContact(contact),
            icon: _creatingLinkedPatient
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.add),
            label: Text(_creatingLinkedPatient ? 'Opening…' : 'Add patient'),
          ),
        ],
      ),
    );
  }

  Widget _linkedPatientsSection(BuildContext context, ZohoContact contact) {
    final linked = contact.linkedPatients;

    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        _sectionLabel(context, 'Linked patients'),
        const SizedBox(height: 6),
        if (linked.isEmpty)
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Text(
              'No linked patients yet.',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          )
        else
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: scheme.outlineVariant),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Column(
              children: [
                for (final p in linked) ...[
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      p.relationship == ContactPatientRelationship.insurance
                          ? Icons.verified_user_outlined
                          : Icons.personal_injury_outlined,
                      color: p.isActive
                          ? scheme.primary
                          : scheme.onSurfaceVariant,
                    ),
                    title: Text(p.patientDisplayName),
                    subtitle: Text(
                      '${p.patientId} • ${_relationshipLabel(p.relationship)}'
                      '${p.isActive ? '' : ' • inactive'}',
                    ),
                    trailing: _openingLinkedPatient
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.chevron_right_rounded),
                    onTap: _openingLinkedPatient
                        ? null
                        : () => _openLinkedPatientEditor(p),
                  ),
                  if (p != linked.last) const Divider(height: 1),
                ],
              ],
            ),
          ),
        const SizedBox(height: 8),
        _selfPatientActionCard(context, contact),
        const SizedBox(height: 8),
        _addLinkedPatientActionCard(context, contact),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _insurancePayerSection(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Column(
      children: [
        _sectionLabel(context, 'Insurance'),
        const SizedBox(height: 6),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
            color: _isInsurancePayer
                ? scheme.primaryContainer.withOpacity(0.35)
                : null,
          ),
          child: SwitchListTile(
            value: _isInsurancePayer,
            onChanged: _readOnly ? null : _setInsurancePayer,
            secondary: Icon(
              Icons.verified_user_outlined,
              color: _isInsurancePayer ? scheme.primary : null,
            ),
            title: const Text('Insurance payer'),
            subtitle: Text(
              _isInsurancePayer
                  ? 'This contact can be selected as an insurer/payer for memberships and claims.'
                  : 'Turn on for insurers such as Britam, CIC, AAR, Jubilee, etc.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _copyToClipboard(String text) async {
    final v = text.trim();
    if (v.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: v));
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Copied')));
  }

  Widget _debugRow({required String label, required String value}) {
    final t = Theme.of(context).textTheme;
    final v = value.trim();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(flex: 4, child: Text(label, style: t.labelMedium)),
          Expanded(
            flex: 6,
            child: Align(
              alignment: Alignment.centerRight,
              child: SelectableText(
                v.isEmpty ? '-' : v,
                style: t.bodyMedium,
                textAlign: TextAlign.right,
              ),
            ),
          ),
          const SizedBox(width: 6),
          IconButton(
            tooltip: 'Copy',
            icon: const Icon(Icons.copy, size: 18),
            onPressed: v.isEmpty ? null : () => _copyToClipboard(v),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final c = widget.initial;
    final contactId = (c?.contactId ?? '').trim();
    final accountNo = (c?.accountNumber ?? _acctCtl.text).trim();
    final contactType = (c?.contactType ?? '').trim();
    final status = (c?.status ?? '').trim();
    final personId = (c?.personContact?.contactPersonId ?? '').trim();
    final linkedCount = c?.activeLinkedPatientCount ?? 0;
    final insuranceLinkedCount = c?.activeInsuranceLinkedPatientCount ?? 0;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Text(_title(), style: Theme.of(context).textTheme.titleLarge),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 88 + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      if (c != null) _linkedPatientsSection(context, c),

                      _sectionLabel(context, 'Basics'),
                      const SizedBox(height: 6),

                      TextFormField(
                        controller: _displayCtl,
                        readOnly: _readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Display name *',
                          hintText: 'e.g. Danab TMC / Dr Ahmed / ABC Trading',
                          prefixIcon: Icon(Icons.badge_outlined),
                        ),
                        validator: (v) {
                          final t = (v ?? '').trim();
                          if (t.isEmpty) return 'Display name is required';
                          return null;
                        },
                        textInputAction: TextInputAction.next,
                      ),
                      const SizedBox(height: 8),

                      TextFormField(
                        controller: _companyCtl,
                        readOnly: _readOnly,
                        decoration: InputDecoration(
                          labelText: 'Company name (optional)',
                          prefixIcon: const Icon(Icons.business_outlined),
                          suffixIcon: IconButton(
                            tooltip: 'Use as display name',
                            onPressed: _readOnly ? null : _useCompanyAsDisplay,
                            icon: const Icon(Icons.north_west),
                          ),
                        ),
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _acctCtl,
                        readOnly: _readOnly,
                        decoration: const InputDecoration(
                          labelText: 'Account No. (optional)',
                          hintText: 'e.g. AC-K4D7-P9Q',
                          prefixIcon: Icon(Icons.confirmation_number_outlined),
                        ),
                        textInputAction: TextInputAction.next,
                      ),

                      const SizedBox(height: 16),
                      _insurancePayerSection(context),

                      _sectionLabel(context, 'Contact type'),
                      const SizedBox(height: 6),

                      SegmentedButton<_ContactKind>(
                        segments: const [
                          ButtonSegment(
                            value: _ContactKind.person,
                            label: Text('Person'),
                            icon: Icon(Icons.person_outline),
                          ),
                          ButtonSegment(
                            value: _ContactKind.companyOnly,
                            label: Text('Company only'),
                            icon: Icon(Icons.apartment_outlined),
                          ),
                        ],
                        selected: {_kind},
                        onSelectionChanged: _readOnly
                            ? null
                            : (sel) => _setKind(sel.first),
                      ),

                      const SizedBox(height: 16),

                      if (_kind == _ContactKind.person) ...[
                        _sectionLabel(context, 'Primary contact person'),
                        const SizedBox(height: 6),

                        TextFormField(
                          controller: _personCtl,
                          readOnly: _readOnly,
                          decoration: InputDecoration(
                            labelText: 'Person name *',
                            hintText: 'e.g. Ahmed Ali',
                            prefixIcon: const Icon(Icons.person_outline),
                            suffixIcon: IconButton(
                              tooltip: 'Use as display name',
                              onPressed: _readOnly ? null : _usePersonAsDisplay,
                              icon: const Icon(Icons.north_west),
                            ),
                          ),
                          validator: (v) {
                            if (_kind != _ContactKind.person) return null;
                            final t = (v ?? '').trim();
                            if (t.isEmpty) return 'Person name is required';
                            return null;
                          },
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _emailCtl,
                          readOnly: _readOnly,
                          keyboardType: TextInputType.emailAddress,
                          decoration: const InputDecoration(
                            labelText: 'Email',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _phoneCtl,
                          readOnly: _readOnly,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Phone',
                            prefixIcon: Icon(Icons.call_outlined),
                          ),
                          textInputAction: TextInputAction.next,
                        ),

                        const SizedBox(height: 8),

                        TextFormField(
                          controller: _mobileCtl,
                          readOnly: _readOnly,
                          keyboardType: TextInputType.phone,
                          decoration: const InputDecoration(
                            labelText: 'Mobile',
                            prefixIcon: Icon(Icons.smartphone_outlined),
                          ),
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_readOnly && _canSave) _emitSave();
                          },
                        ),
                      ],

                      const SizedBox(height: 16),

                      if (_isExisting) ...[
                        _sectionLabel(context, 'Debug'),
                        const SizedBox(height: 6),
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: Theme.of(
                                context,
                              ).dividerColor.withOpacity(0.6),
                            ),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          child: Column(
                            children: [
                              _debugRow(label: 'contactId', value: contactId),
                              _debugRow(
                                label: 'accountNumber',
                                value: accountNo,
                              ),
                              _debugRow(
                                label: 'isInsurancePayer',
                                value: _isInsurancePayer ? 'true' : 'false',
                              ),
                              _debugRow(
                                label: 'contactPersonId',
                                value: personId,
                              ),
                              _debugRow(
                                label: 'contactType',
                                value: contactType,
                              ),
                              _debugRow(label: 'status', value: status),
                              _debugRow(
                                label: 'linkedPatients',
                                value: '$linkedCount',
                              ),
                              _debugRow(
                                label: 'insuranceLinks',
                                value: '$insuranceLinkedCount',
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                      ],

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),
            _ActionBar(
              isExisting: _isExisting,
              editing: _editing,
              readOnly: _readOnly,
              canSave: _canSave,
              onEdit: () => _toggleEdit(true),
              onCancelEdit: () {
                _resetFromInitial();
                _toggleEdit(false);
              },
              onSave: _emitSave,
              onCreate: _emitSave,
              onDelete: _emitDelete,
            ),
          ],
        ),
      ),
    );
  }
}

class _ActionBar extends StatelessWidget {
  const _ActionBar({
    required this.isExisting,
    required this.editing,
    required this.readOnly,
    required this.canSave,
    required this.onEdit,
    required this.onCancelEdit,
    required this.onSave,
    required this.onCreate,
    required this.onDelete,
  });

  final bool isExisting;
  final bool editing;
  final bool readOnly;
  final bool canSave;

  final VoidCallback onEdit;
  final VoidCallback onCancelEdit;
  final VoidCallback onSave;
  final VoidCallback onCreate;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;

    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            if (isExisting)
              OutlinedButton.icon(
                onPressed: onDelete,
                icon: Icon(Icons.delete_outline, color: danger),
                label: Text('Delete', style: TextStyle(color: danger)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: danger.withOpacity(0.7)),
                ),
              ),
            const Spacer(),
            if (!isExisting)
              FilledButton(
                onPressed: canSave && !readOnly ? onCreate : null,
                child: const Text('Create'),
              )
            else if (!editing)
              FilledButton(onPressed: onEdit, child: const Text('Edit'))
            else ...[
              OutlinedButton(
                onPressed: onCancelEdit,
                child: const Text('Cancel'),
              ),
              const SizedBox(width: 10),
              FilledButton(
                onPressed: canSave && !readOnly ? onSave : null,
                child: const Text('Save'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
