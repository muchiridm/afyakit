import 'package:flutter/material.dart';
import 'package:afyakit/features/records/native_contacts/models/native_contact.dart';
import 'contact_sheet_models.dart';

/// Native Contact editor. Login-verified fields and account ID are read-only.
/// Health Profile management lives in its own feature.
class ContactEditorSheet extends StatefulWidget {
  const ContactEditorSheet({super.key, this.initial});
  final NativeContact? initial;

  @override
  State<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<ContactEditorSheet> {
  final _key = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: widget.initial?.displayName ?? '',
  );
  late final _company = TextEditingController(
    text: widget.initial?.companyName ?? '',
  );
  late final _phone = TextEditingController(text: widget.initial?.phone ?? '');
  late final _mobile = TextEditingController(
    text: widget.initial?.mobile ?? '',
  );
  late final _email = TextEditingController(text: widget.initial?.email ?? '');
  late final _idNumber = TextEditingController(
    text: widget.initial?.idNumber ?? '',
  );
  late String _entityType = widget.initial?.entityType == 'company'
      ? 'company'
      : 'person';
  late bool _payer = widget.initial?.isInsurancePayer ?? false;
  late bool _editing = widget.initial == null;

  @override
  void dispose() {
    for (final ctl in [_name, _company, _phone, _mobile, _email, _idNumber]) {
      ctl.dispose();
    }
    super.dispose();
  }

  void _save() {
    if (_key.currentState?.validate() != true) return;
    String? optional(TextEditingController ctl) {
      final value = ctl.text.trim();
      return value.isEmpty ? null : value;
    }

    // Deliberately excludes contact_id, account_number, verified_phone,
    // verified_email, auth_uid, app_ids, status and Zoho IDs.
    final draft = <String, Object?>{
      'display_name': _name.text.trim(),
      'entity_type': _entityType,
      'company_name': optional(_company),
      'phone': optional(_phone),
      'mobile': optional(_mobile),
      'email': optional(_email),
      'id_number': optional(_idNumber),
      'is_insurance_payer': _payer,
    };
    Navigator.of(context).pop(ContactSheetResult.saveRequested(draft));
  }

  @override
  Widget build(BuildContext context) {
    final existing = widget.initial;
    final readOnly = existing != null && !_editing;
    InputDecoration decoration(String label) =>
        InputDecoration(labelText: label);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          16,
          12,
          16,
          MediaQuery.viewInsetsOf(context).bottom + 16,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .75,
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      existing == null ? 'New contact' : 'Native Contact',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              Expanded(
                child: Form(
                  key: _key,
                  child: ListView(
                    children: [
                      if (existing != null) ...[
                        ListTile(
                          title: const Text('Account number'),
                          subtitle: SelectableText(
                            existing.accountNumber ?? existing.id,
                          ),
                        ),
                        if ((existing.verifiedPhone ?? '').isNotEmpty)
                          ListTile(
                            title: const Text('Verified phone (read-only)'),
                            subtitle: Text(existing.verifiedPhone!),
                          ),
                        if ((existing.verifiedEmail ?? '').isNotEmpty)
                          ListTile(
                            title: const Text('Verified app email (read-only)'),
                            subtitle: Text(existing.verifiedEmail!),
                          ),
                      ],
                      TextFormField(
                        controller: _name,
                        readOnly: readOnly,
                        decoration: decoration('Display name *'),
                        validator: (v) =>
                            (v ?? '').trim().isEmpty ? 'Required' : null,
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        value: _entityType,
                        decoration: decoration('Entity type'),
                        items: const [
                          DropdownMenuItem(
                            value: 'person',
                            child: Text('Person'),
                          ),
                          DropdownMenuItem(
                            value: 'company',
                            child: Text('Company'),
                          ),
                        ],
                        onChanged: readOnly
                            ? null
                            : (v) =>
                                  setState(() => _entityType = v ?? 'person'),
                      ),
                      const SizedBox(height: 12),
                      if (_entityType == 'company')
                        TextFormField(
                          controller: _company,
                          readOnly: readOnly,
                          decoration: decoration('Company name'),
                        ),
                      TextFormField(
                        controller: _phone,
                        readOnly: readOnly,
                        decoration: decoration('Contact phone'),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: _mobile,
                        readOnly: readOnly,
                        decoration: decoration('Mobile'),
                        keyboardType: TextInputType.phone,
                      ),
                      TextFormField(
                        controller: _email,
                        readOnly: readOnly,
                        decoration: decoration('Contact email'),
                        keyboardType: TextInputType.emailAddress,
                      ),
                      TextFormField(
                        controller: _idNumber,
                        readOnly: readOnly,
                        decoration: decoration('ID number'),
                      ),
                      SwitchListTile(
                        title: const Text('Insurance payer'),
                        value: _payer,
                        onChanged: readOnly
                            ? null
                            : (value) => setState(() => _payer = value),
                      ),
                    ],
                  ),
                ),
              ),
              Row(
                children: [
                  if (existing != null)
                    TextButton.icon(
                      onPressed: () => Navigator.pop(
                        context,
                        ContactSheetResult.deleteRequested(existing.id),
                      ),
                      icon: const Icon(Icons.person_remove_outlined),
                      label: const Text('Remove from app'),
                    ),
                  const Spacer(),
                  if (readOnly)
                    FilledButton(
                      onPressed: () => setState(() => _editing = true),
                      child: const Text('Edit'),
                    )
                  else
                    FilledButton(
                      onPressed: _save,
                      child: Text(existing == null ? 'Create' : 'Save'),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
