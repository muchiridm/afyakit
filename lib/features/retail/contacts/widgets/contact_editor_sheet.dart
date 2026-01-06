// lib/features/retail/contacts/widgets/contact_editor_sheet.dart

import 'package:flutter/material.dart';

import '../models/zoho_contact.dart';
import 'contact_sheet_models.dart';

class ContactEditorSheet extends StatefulWidget {
  const ContactEditorSheet({super.key, this.initial});

  final ZohoContact? initial;

  @override
  State<ContactEditorSheet> createState() => _ContactEditorSheetState();
}

class _ContactEditorSheetState extends State<ContactEditorSheet> {
  late final TextEditingController _displayCtl;
  late final TextEditingController _personCtl;
  late final TextEditingController _companyCtl;
  late final TextEditingController _emailCtl;
  late final TextEditingController _phoneCtl;
  late final TextEditingController _mobileCtl;

  bool _editing = false;

  bool get _isExisting => widget.initial != null;
  bool get _readOnly => _isExisting && !_editing;
  bool get _canSave => _displayCtl.text.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    final c = widget.initial;

    _editing = c == null; // new contact starts in edit mode

    _displayCtl = TextEditingController(text: c?.displayName ?? '');
    _personCtl = TextEditingController(text: c?.personName ?? '');
    _companyCtl = TextEditingController(text: c?.companyName ?? '');
    _emailCtl = TextEditingController(text: c?.email ?? '');
    _phoneCtl = TextEditingController(text: c?.phone ?? '');
    _mobileCtl = TextEditingController(text: c?.mobile ?? '');

    // purely UI: enable/disable Save based on display name
    _displayCtl.addListener(() {
      if (!mounted) return;
      setState(() {});
    });
  }

  @override
  void dispose() {
    _displayCtl.dispose();
    _personCtl.dispose();
    _companyCtl.dispose();
    _emailCtl.dispose();
    _phoneCtl.dispose();
    _mobileCtl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // UI-only actions (no dialogs/snacks)
  // ─────────────────────────────────────────────

  void _toggleEdit(bool v) {
    if (!mounted) return;
    setState(() => _editing = v);
  }

  void _resetFromInitial() {
    final c = widget.initial;
    _displayCtl.text = c?.displayName ?? '';
    _personCtl.text = c?.personName ?? '';
    _companyCtl.text = c?.companyName ?? '';
    _emailCtl.text = c?.email ?? '';
    _phoneCtl.text = c?.phone ?? '';
    _mobileCtl.text = c?.mobile ?? '';
  }

  ZohoContact _buildDraft() {
    final display = _displayCtl.text.trim();
    final person = _personCtl.text.trim();
    final company = _companyCtl.text.trim();

    return ZohoContact(
      contactId: widget.initial?.contactId ?? '',
      displayName: display,
      personName: person.isEmpty ? null : person,
      companyName: company.isEmpty ? null : company,
      email: _emailCtl.text.trim().isEmpty ? null : _emailCtl.text.trim(),
      phone: _phoneCtl.text.trim().isEmpty ? null : _phoneCtl.text.trim(),
      mobile: _mobileCtl.text.trim().isEmpty ? null : _mobileCtl.text.trim(),
      status: widget.initial?.status,
    );
  }

  void _emitSave() {
    Navigator.of(context).pop(ContactSheetResult.saveRequested(_buildDraft()));
  }

  void _emitDelete() {
    final id = widget.initial?.contactId.trim() ?? '';
    if (id.isEmpty) return; // UI guard
    Navigator.of(context).pop(ContactSheetResult.deleteRequested(id));
  }

  // ─────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────

  String _title() {
    if (!_isExisting) return 'New Contact';
    return _editing ? 'Edit Contact' : 'Contact';
  }

  Widget _headerRow(BuildContext context) {
    return Row(
      children: [
        Text(_title(), style: Theme.of(context).textTheme.titleLarge),
        const Spacer(),
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.close),
        ),
      ],
    );
  }

  Widget _field({
    required TextEditingController controller,
    required String label,
    String? hint,
    TextInputType? keyboardType,
    TextInputAction? action,
    void Function(String)? onSubmitted,
  }) {
    return TextField(
      controller: controller,
      readOnly: _readOnly,
      decoration: InputDecoration(labelText: label, hintText: hint),
      keyboardType: keyboardType,
      textInputAction: action,
      onSubmitted: onSubmitted,
    );
  }

  Widget _createActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton(
          onPressed: _canSave ? _emitSave : null,
          child: const Text('Create'),
        ),
      ],
    );
  }

  Widget _viewActions(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        FilledButton(
          onPressed: () => _toggleEdit(true),
          child: const Text('Edit'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _emitDelete,
          icon: Icon(Icons.delete_outline, color: danger),
          label: Text('Delete', style: TextStyle(color: danger)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: danger.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }

  Widget _editActions(BuildContext context) {
    final danger = Theme.of(context).colorScheme.error;

    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        OutlinedButton(
          onPressed: () {
            _resetFromInitial();
            _toggleEdit(false);
          },
          child: const Text('Cancel'),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _canSave ? _emitSave : null,
          child: const Text('Save'),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          onPressed: _emitDelete,
          icon: Icon(Icons.delete_outline, color: danger),
          label: Text('Delete', style: TextStyle(color: danger)),
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: danger.withOpacity(0.7)),
          ),
        ),
      ],
    );
  }

  Widget _actions(BuildContext context) {
    if (!_isExisting) return _createActions();
    if (!_editing) return _viewActions(context);
    return _editActions(context);
  }

  // ─────────────────────────────────────────────
  // Build (lean)
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 12,
          bottom: 12 + MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _headerRow(context),
              const SizedBox(height: 8),
              _field(
                controller: _displayCtl,
                label: 'Display name *',
                hint: 'e.g. Danab TMC / Dr Ahmed / ABC Trading',
                action: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              _field(
                controller: _personCtl,
                label: 'Contact name (optional)',
                hint: 'Person name if applicable',
                action: TextInputAction.next,
              ),
              _field(
                controller: _companyCtl,
                label: 'Company name (optional)',
                hint: 'Company / organization',
                action: TextInputAction.next,
              ),
              const SizedBox(height: 8),
              _field(
                controller: _emailCtl,
                label: 'Email',
                keyboardType: TextInputType.emailAddress,
                action: TextInputAction.next,
              ),
              _field(
                controller: _phoneCtl,
                label: 'Phone',
                keyboardType: TextInputType.phone,
                action: TextInputAction.next,
              ),
              _field(
                controller: _mobileCtl,
                label: 'Mobile',
                keyboardType: TextInputType.phone,
                action: TextInputAction.done,
                onSubmitted: (_) {
                  if (!_readOnly && _canSave) _emitSave();
                },
              ),
              const SizedBox(height: 16),
              _actions(context),
            ],
          ),
        ),
      ),
    );
  }
}
