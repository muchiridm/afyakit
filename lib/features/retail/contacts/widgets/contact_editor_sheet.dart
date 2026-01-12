// lib/features/retail/contacts/widgets/contact_editor_sheet.dart

import 'package:flutter/material.dart';

import '../models/zoho_contact.dart';
import 'contact_sheet_models.dart';

enum _ContactKind { person, companyOnly }

class ContactEditorSheet extends StatefulWidget {
  const ContactEditorSheet({super.key, this.initial});

  final ZohoContact? initial;

  @override
  State<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<ContactEditorSheet> {
  final _formKey = GlobalKey<FormState>();

  late final TextEditingController _displayCtl;
  late final TextEditingController _companyCtl;

  // personContact fields
  late final TextEditingController _personCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _mobileCtl;

  bool _editing = false;
  late _ContactKind _kind;

  bool get _isExisting => widget.initial != null;
  bool get _readOnly => _isExisting && !_editing;

  bool get _canSave => _displayCtl.text.trim().isNotEmpty && !_readOnly;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;

    _editing = c == null; // new contact starts in edit mode

    _displayCtl = TextEditingController(text: c?.displayName ?? '');
    _companyCtl = TextEditingController(text: c?.companyName ?? '');

    final pc = c?.personContact;
    _personCtl = TextEditingController(text: pc?.personName ?? '');
    _emailCtl = TextEditingController(text: pc?.email ?? '');
    _phoneCtl = TextEditingController(text: pc?.phone ?? '');
    _mobileCtl = TextEditingController(text: pc?.mobile ?? '');

    _kind = (pc == null) ? _ContactKind.companyOnly : _ContactKind.person;

    // update Save enabled state
    _displayCtl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _displayCtl.dispose();
    _companyCtl.dispose();
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

    final pc = c?.personContact;
    _personCtl.text = pc?.personName ?? '';
    _emailCtl.text = pc?.email ?? '';
    _phoneCtl.text = pc?.phone ?? '';
    _mobileCtl.text = pc?.mobile ?? '';

    _kind = (pc == null) ? _ContactKind.companyOnly : _ContactKind.person;
  }

  void _setKind(_ContactKind next) {
    if (_readOnly) return;
    setState(() {
      _kind = next;
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

    final person = _personCtl.text.trim();
    final email = _emailCtl.text.trim();
    final phone = _phoneCtl.text.trim();
    final mobile = _mobileCtl.text.trim();

    PersonContact? personContact;
    if (_kind == _ContactKind.person) {
      // allow "person mode" even if comms exist and name empty?
      // no — we validate person name (see validators below)
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

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.only(left: 16, right: 16, top: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header row
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

            // Body
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.only(bottom: 88 + bottomInset),
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
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

                      const SizedBox(height: 12),
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

                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),
            ),

            // Sticky action bar
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
