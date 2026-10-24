import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hq_tenant_contacts_controller.dart';
import 'hq_tenant_contacts_providers.dart';
import 'hq_tenant_contacts_service.dart';

/// Tenant-wide directory. Archive is a reversible logical delete, not a purge.
class HqTenantContactsScreen extends ConsumerStatefulWidget {
  const HqTenantContactsScreen({super.key, required this.tenantId});
  final String tenantId;
  @override
  ConsumerState<HqTenantContactsScreen> createState() => _HqTenantContactsScreenState();
}

class _HqTenantContactsScreenState extends ConsumerState<HqTenantContactsScreen> {
  final _search = TextEditingController();
  final _rows = <HqTenantContact>[];
  String? _cursor;
  bool _loading = false, _hasMore = true;
  String? _error;

  @override
  void initState() { super.initState(); Future.microtask(_reload); }
  @override
  void dispose() { _search.dispose(); super.dispose(); }

  Future<void> _reload() async {
    if (_loading) return;
    setState(() { _rows.clear(); _cursor = null; _hasMore = true; _error = null; });
    await _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final service = await ref.read(hqTenantContactsServiceProvider.future);
      final page = await service.list(widget.tenantId, limit: 50, cursor: _cursor);
      if (!mounted) return;
      setState(() {
        _rows.addAll(page.contacts);
        _cursor = page.nextCursor;
        _hasMore = _cursor != null && page.contacts.isNotEmpty;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = '$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit(HqTenantContact? contact) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) => _ContactEditor(tenantId: widget.tenantId, contact: contact),
    );
    if (changed == true) await _reload();
  }

  Future<void> _status(HqTenantContact contact) async {
    final isArchive = contact.status == 'active';
    final reason = await _reasonDialog(isArchive ? 'Archive contact' : 'Restore contact');
    if (reason == null || !mounted) return;
    final controller = ref.read(hqTenantContactsControllerProvider.notifier);
    final ok = isArchive
        ? await controller.archive(widget.tenantId, contact.accountNumber, reason)
        : await controller.restore(widget.tenantId, contact.accountNumber, reason);
    if (ok) await _reload();
    if (!ok && mounted) {
      final error = ref.read(hqTenantContactsControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error ?? 'Operation failed')));
    }
  }

  Future<String?> _reasonDialog(String title) async {
    final text = TextEditingController();
    try {
      return await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
        title: Text(title),
        content: SizedBox(width: 420, child: TextField(controller: text, maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (15+ characters)'))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(onPressed: () {
            if (text.text.trim().length >= 15) Navigator.pop(ctx, text.text.trim());
          }, child: const Text('Confirm')),
        ],
      ));
    } finally { text.dispose(); }
  }

  Future<void> _dependencies(HqTenantContact contact) async {
    try {
      final service = await ref.read(hqTenantContactsServiceProvider.future);
      final result = await service.dependencies(widget.tenantId, contact.accountNumber);
      if (!mounted) return;
      await showDialog<void>(context: context, builder: (ctx) => AlertDialog(
        title: const Text('Dependencies and retention'),
        content: SizedBox(width: 460, child: SingleChildScrollView(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min,
          children: [Text(contact.accountNumber), const SizedBox(height: 12),
            if (result.blockers.isEmpty) const Text('No dependencies found in the checked collections.'),
            for (final blocker in result.blockers) Padding(padding: const EdgeInsets.symmetric(vertical: 3), child: Text('• $blocker')),
            const SizedBox(height: 12), const Text('Preview only. Permanent deletion is not authorised.'),
          ],
        ))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close'))],
      ));
    } catch (error) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final filtered = _rows.where((c) => query.isEmpty ||
      c.displayName.toLowerCase().contains(query) ||
      c.accountNumber.toLowerCase().contains(query) ||
      c.appIds.any((app) => app.toLowerCase().contains(query))).toList();
    return Scaffold(
      appBar: AppBar(title: Text('Tenant Contacts · ${widget.tenantId}'), actions: [
        IconButton(tooltip: 'Refresh', onPressed: _loading ? null : _reload, icon: const Icon(Icons.refresh)),
      ]),
      floatingActionButton: FloatingActionButton.extended(onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt_1), label: const Text('New contact')),
      body: Column(children: [
        Padding(padding: const EdgeInsets.all(12), child: TextField(
          controller: _search, onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(prefixIcon: Icon(Icons.search),
            labelText: 'Filter loaded contacts', border: OutlineInputBorder()),
        )),
        const Padding(padding: EdgeInsets.symmetric(horizontal: 12), child: Align(
          alignment: Alignment.centerLeft,
          child: Text('Tenant-wide contacts · archive instead of permanent delete'),
        )),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null) Padding(padding: const EdgeInsets.all(12), child: Text(_error!,
          style: TextStyle(color: Theme.of(context).colorScheme.error))),
        Expanded(child: ListView.builder(itemCount: filtered.length + (_hasMore ? 1 : 0),
          itemBuilder: (ctx, i) {
            if (i == filtered.length) return Center(child: Padding(padding: const EdgeInsets.all(12),
              child: OutlinedButton(onPressed: _loading ? null : _loadMore, child: const Text('Load more'))));
            final c = filtered[i];
            return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: LayoutBuilder(builder: (ctx, constraints) {
                final desktop = constraints.maxWidth >= 660;
                return ListTile(
                  leading: CircleAvatar(child: Icon(c.entityType == 'organization' ? Icons.business_outlined : Icons.person_outline)),
                  title: Text(c.displayName.isEmpty ? c.accountNumber : c.displayName,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text('${c.accountNumber} · ${c.appIds.join(', ')} · ${c.status}'
                    '${c.authLinked ? ' · Auth linked' : ''}',
                    maxLines: 2, overflow: TextOverflow.ellipsis),
                  trailing: desktop ? Wrap(spacing: 4, children: [
                    OutlinedButton.icon(onPressed: () => _dependencies(c), icon: const Icon(Icons.account_tree_outlined, size: 16), label: const Text('Dependencies')),
                    OutlinedButton.icon(onPressed: c.status == 'active' ? () => _edit(c) : null, icon: const Icon(Icons.edit_outlined, size: 16), label: const Text('Edit')),
                    TextButton.icon(onPressed: () => _status(c),
                      icon: Icon(c.status == 'active' ? Icons.archive_outlined : Icons.unarchive_outlined, size: 16),
                      label: Text(c.status == 'active' ? 'Archive' : 'Restore')),
                  ]) : PopupMenuButton<String>(onSelected: (v) {
                    if (v == 'edit') _edit(c);
                    if (v == 'dependencies') _dependencies(c);
                    if (v == 'status') _status(c);
                  }, itemBuilder: (_) => [
                    const PopupMenuItem(value: 'dependencies', child: Text('Dependencies')),
                    if (c.status == 'active') const PopupMenuItem(value: 'edit', child: Text('Edit')),
                    PopupMenuItem(value: 'status', child: Text(c.status == 'active' ? 'Archive' : 'Restore')),
                  ]),
                );
              }),
            );
          },
        )),
      ]),
    );
  }
}

class _ContactEditor extends ConsumerStatefulWidget {
  const _ContactEditor({required this.tenantId, this.contact});
  final String tenantId;
  final HqTenantContact? contact;
  @override
  ConsumerState<_ContactEditor> createState() => _ContactEditorState();
}

class _ContactEditorState extends ConsumerState<_ContactEditor> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(), _app = TextEditingController(),
      _company = TextEditingController(), _phone = TextEditingController(),
      _mobile = TextEditingController(), _email = TextEditingController(),
      _id = TextEditingController();
  String _entity = 'person', _type = 'customer';
  bool _insurance = false;
  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    if (c != null) {
      _name.text = c.displayName; _company.text = c.companyName ?? '';
      _phone.text = c.phone ?? ''; _mobile.text = c.mobile ?? '';
      _email.text = c.email ?? ''; _id.text = c.idNumber ?? '';
      _entity = c.entityType ?? 'person'; _type = c.contactType ?? 'customer';
      _insurance = c.isInsurancePayer;
    }
  }
  @override
  void dispose() {
    for (final c in [_name, _app, _company, _phone, _mobile, _email, _id]) { c.dispose(); }
    super.dispose();
  }
  Widget _field(String label, TextEditingController controller, {bool required = false}) =>
    Padding(padding: const EdgeInsets.only(bottom: 10), child: TextFormField(
      controller: controller, decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
      validator: required ? (s) => (s ?? '').trim().isEmpty ? 'Required' : null : null,
    ));
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final body = <String, Object?>{
      'display_name': _name.text.trim(), 'contact_type': _type,
      'company_name': _company.text.trim().isEmpty ? null : _company.text.trim(),
      'phone': _phone.text.trim().isEmpty ? null : _phone.text.trim(),
      'mobile': _mobile.text.trim().isEmpty ? null : _mobile.text.trim(),
      'email': _email.text.trim().isEmpty ? null : _email.text.trim(),
      'id_number': _id.text.trim().isEmpty ? null : _id.text.trim(),
      'is_insurance_payer': _insurance,
      if (widget.contact == null) 'entity_type': _entity,
      if (widget.contact == null) 'app_id': _app.text.trim().toLowerCase(),
    };
    final controller = ref.read(hqTenantContactsControllerProvider.notifier);
    final ok = widget.contact == null
      ? await controller.create(widget.tenantId, body)
      : await controller.update(widget.tenantId, widget.contact!.accountNumber, body);
    if (ok && mounted) Navigator.pop(context, true);
  }
  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hqTenantContactsControllerProvider);
    return AlertDialog(
      title: Text(widget.contact == null ? 'New tenant contact' : 'Edit ${widget.contact!.accountNumber}'),
      content: SizedBox(width: 520, child: SingleChildScrollView(child: Form(
        key: _form, child: Column(mainAxisSize: MainAxisSize.min, children: [
          _field('Display name', _name, required: true),
          if (widget.contact == null) ...[
            _field('App ID for initial enrolment', _app, required: true),
            DropdownButtonFormField<String>(value: _entity,
              decoration: const InputDecoration(labelText: 'Entity type'),
              items: const [DropdownMenuItem(value: 'person', child: Text('Person')),
                DropdownMenuItem(value: 'organization', child: Text('Organisation'))],
              onChanged: (v) => setState(() => _entity = v ?? 'person')),
          ],
          DropdownButtonFormField<String>(value: _type,
            decoration: const InputDecoration(labelText: 'Contact type'),
            items: const [DropdownMenuItem(value: 'customer', child: Text('Customer')),
              DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
              DropdownMenuItem(value: 'customer_vendor', child: Text('Customer & vendor'))],
            onChanged: (v) => setState(() => _type = v ?? 'customer')),
          const SizedBox(height: 12),
          _field('Company', _company), _field('Phone', _phone), _field('Mobile', _mobile),
          _field('Email', _email), _field('ID / registration number', _id),
          SwitchListTile(title: const Text('Insurance payer'), value: _insurance,
            onChanged: (v) => setState(() => _insurance = v)),
          if (state.error != null) Text(state.error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ]),
      ))),
      actions: [
        TextButton(onPressed: state.busy ? null : () => Navigator.pop(context), child: const Text('Cancel')),
        FilledButton(onPressed: state.busy ? null : _save, child: Text(state.busy ? 'Saving…' : 'Save')),
      ],
    );
  }
}
