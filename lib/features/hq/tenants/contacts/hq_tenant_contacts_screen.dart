import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'hq_tenant_contacts_controller.dart';
import 'hq_tenant_contacts_service.dart';

/// Tenant-wide directory. Archive is a reversible logical delete, not a purge.
class HqTenantContactsScreen extends ConsumerStatefulWidget {
  const HqTenantContactsScreen({super.key, required this.tenantId});
  final String tenantId;
  @override
  ConsumerState<HqTenantContactsScreen> createState() =>
      _HqTenantContactsScreenState();
}

class _HqTenantContactsScreenState
    extends ConsumerState<HqTenantContactsScreen> {
  final _search = TextEditingController();
  final _rows = <HqTenantContact>[];
  bool _loading = false;
  String? _error;
  String? _selectedApp;
  int _loadVersion = 0;

  @override
  void initState() {
    super.initState();
    Future.microtask(_reload);
  }

  @override
  void dispose() {
    _loadVersion++;
    _search.dispose();
    super.dispose();
  }

  // Load the full tenant directory so counts, app filters and A–Z sorting
  // apply to every contact, not just the first page.
  Future<void> _reload() async {
    final version = ++_loadVersion;
    setState(() {
      _loading = true;
      _error = null;
      _rows.clear();
    });

    try {
      final service = await ref.read(hqTenantContactsServiceProvider.future);
      String? cursor;
      final seenCursors = <String>{};
      final contacts = <String, HqTenantContact>{};

      while (true) {
        final page = await service.list(
          widget.tenantId,
          limit: 100,
          cursor: cursor,
        );
        if (!mounted || version != _loadVersion) return;

        for (final contact in page.contacts) {
          contacts[contact.accountNumber] = contact;
        }
        setState(() {
          _rows
            ..clear()
            ..addAll(contacts.values);
        });

        final next = page.nextCursor;
        if (next == null || next.isEmpty) break;
        if (!seenCursors.add(next)) {
          throw StateError('Repeated contacts pagination cursor');
        }
        cursor = next;
      }
    } catch (error) {
      if (mounted && version == _loadVersion) {
        setState(() => _error = '$error');
      }
    } finally {
      if (mounted && version == _loadVersion) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _edit(HqTenantContact? contact) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          _ContactEditor(tenantId: widget.tenantId, contact: contact),
    );
    if (changed == true) await _reload();
  }

  Future<void> _status(HqTenantContact contact) async {
    final isArchive = contact.status == 'active';
    final reason = await _reasonDialog(
      isArchive ? 'Archive contact' : 'Restore contact',
    );
    if (reason == null || !mounted) return;
    final controller = ref.read(hqTenantContactsControllerProvider.notifier);
    final ok = isArchive
        ? await controller.archive(
            widget.tenantId,
            contact.accountNumber,
            reason,
          )
        : await controller.restore(
            widget.tenantId,
            contact.accountNumber,
            reason,
          );
    if (ok) await _reload();
    if (!ok && mounted) {
      final error = ref.read(hqTenantContactsControllerProvider).error;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error ?? 'Operation failed')));
    }
  }

  Future<String?> _reasonDialog(String title) async {
    final text = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: SizedBox(
            width: 420,
            child: TextField(
              controller: text,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Reason (15+ characters)',
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                if (text.text.trim().length >= 15)
                  Navigator.pop(ctx, text.text.trim());
              },
              child: const Text('Confirm'),
            ),
          ],
        ),
      );
    } finally {
      text.dispose();
    }
  }

  Future<void> _dependencies(HqTenantContact contact) async {
    try {
      final service = await ref.read(hqTenantContactsServiceProvider.future);
      final result = await service.dependencies(
        widget.tenantId,
        contact.accountNumber,
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Dependencies and retention'),
          content: SizedBox(
            width: 460,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(contact.accountNumber),
                  const SizedBox(height: 12),
                  if (result.blockers.isEmpty)
                    const Text(
                      'No dependencies found in the checked collections.',
                    ),
                  for (final blocker in result.blockers)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Text('• $blocker'),
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Preview only. Permanent deletion is not authorised.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<void> _deletionWorkflow(HqTenantContact contact) async {
    try {
      final service = await ref.read(hqTenantContactsServiceProvider.future);
      final result = await service.dependencies(
        widget.tenantId,
        contact.accountNumber,
      );
      if (!mounted) return;
      final blockers = result.blockers;
      final proceed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Permanently delete ${contact.accountNumber}?'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Contact: ${contact.displayName}'),
                  const SizedBox(height: 12),
                  if (blockers.isNotEmpty) ...[
                    const Text('Resolve these dependencies first:'),
                    for (final blocker in blockers) Text('• $blocker'),
                  ] else
                    const Text(
                      'No dependencies found in the preview. The server will check again before deletion.',
                    ),
                  const SizedBox(height: 12),
                  const Text(
                    'Permanent deletion is irreversible. Linked clinical or financial records are NOT automatically removed.',
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Close'),
            ),
            if (blockers.isEmpty && contact.status == 'inactive')
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Continue'),
              ),
          ],
        ),
      );
      if (proceed != true || !mounted) return;
      final reason = await _confirmPermanentDelete(contact.accountNumber);
      if (reason == null || !mounted) return;
      final ctrl = ref.read(hqTenantContactsControllerProvider.notifier);
      final ok = await ctrl.permanentlyDelete(
        widget.tenantId,
        contact.accountNumber,
        reason,
      );
      if (ok) await _reload();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ok
                ? 'Contact permanently deleted.'
                : ref.read(hqTenantContactsControllerProvider).error ??
                      'Deletion blocked',
          ),
        ),
      );
    } catch (error) {
      if (mounted)
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
    }
  }

  Future<String?> _confirmPermanentDelete(String accountNumber) async {
    final confirmation = TextEditingController();
    final reason = TextEditingController();
    try {
      return await showDialog<String>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (ctx, redraw) {
            final valid =
                confirmation.text.trim().toUpperCase() == accountNumber &&
                reason.text.trim().length >= 15 &&
                reason.text.trim().length <= 1000;
            return AlertDialog(
              title: const Text('Confirm permanent deletion'),
              content: SizedBox(
                width: 460,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Type $accountNumber to confirm irreversible deletion.',
                    ),
                    TextField(
                      controller: confirmation,
                      onChanged: (_) => redraw(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Account number',
                      ),
                    ),
                    TextField(
                      controller: reason,
                      onChanged: (_) => redraw(() {}),
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Reason (15–1000 characters)',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: valid
                      ? () => Navigator.pop(ctx, reason.text.trim())
                      : null,
                  child: const Text('Permanently delete'),
                ),
              ],
            );
          },
        ),
      );
    } finally {
      confirmation.dispose();
      reason.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final query = _search.text.trim().toLowerCase();
    final apps = _rows.expand((c) => c.appIds).toSet().toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    final selectedApp = apps.contains(_selectedApp) ? _selectedApp : null;
    final filtered =
        _rows.where((c) {
          final matchesApp =
              selectedApp == null || c.appIds.contains(selectedApp);
          final matchesSearch =
              query.isEmpty ||
              c.displayName.toLowerCase().contains(query) ||
              c.accountNumber.toLowerCase().contains(query) ||
              c.appIds.any((app) => app.toLowerCase().contains(query));
          return matchesApp && matchesSearch;
        }).toList()..sort((a, b) {
          final aName = a.displayName.trim().isEmpty
              ? a.accountNumber
              : a.displayName.trim();
          final bName = b.displayName.trim().isEmpty
              ? b.accountNumber
              : b.displayName.trim();
          final byName = aName.toLowerCase().compareTo(bName.toLowerCase());
          return byName != 0
              ? byName
              : a.accountNumber.compareTo(b.accountNumber);
        });
    return Scaffold(
      appBar: AppBar(
        title: Text('Tenant Contacts · ${widget.tenantId}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading ? null : _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(null),
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New contact'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                SizedBox(
                  width: 300,
                  child: TextField(
                    controller: _search,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      labelText: 'Search contacts',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                SizedBox(
                  width: 230,
                  child: DropdownButtonFormField<String>(
                    key: ValueKey(selectedApp ?? '__all__'),
                    initialValue: selectedApp ?? '',
                    isExpanded: true,
                    decoration: const InputDecoration(
                      labelText: 'Application',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: Text('All applications'),
                      ),
                      for (final app in apps)
                        DropdownMenuItem(value: app, child: Text(app)),
                    ],
                    onChanged: (value) => setState(() {
                      _selectedApp = value == null || value.isEmpty
                          ? null
                          : value;
                    }),
                  ),
                ),
                Text(
                  _loading
                      ? 'Loading contacts… ${_rows.length} loaded'
                      : 'Contacts: ${_rows.length}  ·  Showing: ${filtered.length}',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const Text('Name: A–Z'),
              ],
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          Expanded(
            child: ListView.builder(
              itemCount: filtered.length,
              itemBuilder: (ctx, i) {
                final c = filtered[i];
                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: LayoutBuilder(
                    builder: (ctx, constraints) {
                      final desktop = constraints.maxWidth >= 660;
                      return ListTile(
                        leading: CircleAvatar(
                          child: Icon(
                            c.entityType == 'organization'
                                ? Icons.business_outlined
                                : Icons.person_outline,
                          ),
                        ),
                        title: Text(
                          c.displayName.isEmpty
                              ? c.accountNumber
                              : c.displayName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          '${c.accountNumber} · ${c.appIds.join(', ')} · ${c.status}'
                          '${c.authLinked ? ' · Auth linked' : ''}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: desktop
                            ? Wrap(
                                spacing: 4,
                                children: [
                                  OutlinedButton.icon(
                                    onPressed: () => _dependencies(c),
                                    icon: const Icon(
                                      Icons.account_tree_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Dependencies'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: c.status == 'active'
                                        ? () => _edit(c)
                                        : null,
                                    icon: const Icon(
                                      Icons.edit_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Edit'),
                                  ),
                                  if (c.status == 'inactive')
                                    TextButton.icon(
                                      onPressed: () => _deletionWorkflow(c),
                                      icon: const Icon(
                                        Icons.fact_check_outlined,
                                        size: 16,
                                      ),
                                      label: const Text('Permanent delete'),
                                    ),
                                  TextButton.icon(
                                    onPressed: () => _status(c),
                                    icon: Icon(
                                      c.status == 'active'
                                          ? Icons.archive_outlined
                                          : Icons.unarchive_outlined,
                                      size: 16,
                                    ),
                                    label: Text(
                                      c.status == 'active'
                                          ? 'Archive'
                                          : 'Restore',
                                    ),
                                  ),
                                ],
                              )
                            : PopupMenuButton<String>(
                                onSelected: (v) {
                                  if (v == 'edit') _edit(c);
                                  if (v == 'dependencies') _dependencies(c);
                                  if (v == 'status') _status(c);
                                  if (v == 'deletion') _deletionWorkflow(c);
                                },
                                itemBuilder: (_) => [
                                  const PopupMenuItem(
                                    value: 'dependencies',
                                    child: Text('Dependencies'),
                                  ),
                                  if (c.status == 'active')
                                    const PopupMenuItem(
                                      value: 'edit',
                                      child: Text('Edit'),
                                    ),
                                  PopupMenuItem(
                                    value: 'status',
                                    child: Text(
                                      c.status == 'active'
                                          ? 'Archive'
                                          : 'Restore',
                                    ),
                                  ),
                                  if (c.status == 'inactive')
                                    const PopupMenuItem(
                                      value: 'deletion',
                                      child: Text('Permanent delete'),
                                    ),
                                ],
                              ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
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
  final _name = TextEditingController(),
      _app = TextEditingController(),
      _company = TextEditingController(),
      _phone = TextEditingController(),
      _mobile = TextEditingController(),
      _email = TextEditingController(),
      _id = TextEditingController();
  String _entity = 'person', _type = 'customer';
  bool _insurance = false;
  @override
  void initState() {
    super.initState();
    final c = widget.contact;
    if (c != null) {
      _name.text = c.displayName;
      _company.text = c.companyName ?? '';
      _phone.text = c.phone ?? '';
      _mobile.text = c.mobile ?? '';
      _email.text = c.email ?? '';
      _id.text = c.idNumber ?? '';
      _entity = c.entityType ?? 'person';
      _type = c.contactType ?? 'customer';
      _insurance = c.isInsurancePayer;
    }
  }

  @override
  void dispose() {
    for (final c in [_name, _app, _company, _phone, _mobile, _email, _id]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    String label,
    TextEditingController controller, {
    bool required = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (s) => (s ?? '').trim().isEmpty ? 'Required' : null
          : null,
    ),
  );
  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final body = <String, Object?>{
      'display_name': _name.text.trim(),
      'contact_type': _type,
      'company_name': _company.text.trim().isEmpty
          ? null
          : _company.text.trim(),
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
        : await controller.update(
            widget.tenantId,
            widget.contact!.accountNumber,
            body,
          );
    if (ok && mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(hqTenantContactsControllerProvider);
    return AlertDialog(
      title: Text(
        widget.contact == null
            ? 'New tenant contact'
            : 'Edit ${widget.contact!.accountNumber}',
      ),
      content: SizedBox(
        width: 520,
        child: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _field('Display name', _name, required: true),
                if (widget.contact == null) ...[
                  _field('App ID for initial enrolment', _app, required: true),
                  DropdownButtonFormField<String>(
                    value: _entity,
                    decoration: const InputDecoration(labelText: 'Entity type'),
                    items: const [
                      DropdownMenuItem(value: 'person', child: Text('Person')),
                      DropdownMenuItem(
                        value: 'organization',
                        child: Text('Organisation'),
                      ),
                    ],
                    onChanged: (v) => setState(() => _entity = v ?? 'person'),
                  ),
                ],
                DropdownButtonFormField<String>(
                  value: _type,
                  decoration: const InputDecoration(labelText: 'Contact type'),
                  items: const [
                    DropdownMenuItem(
                      value: 'customer',
                      child: Text('Customer'),
                    ),
                    DropdownMenuItem(value: 'vendor', child: Text('Vendor')),
                    DropdownMenuItem(
                      value: 'customer_vendor',
                      child: Text('Customer & vendor'),
                    ),
                  ],
                  onChanged: (v) => setState(() => _type = v ?? 'customer'),
                ),
                const SizedBox(height: 12),
                _field('Company', _company),
                _field('Phone', _phone),
                _field('Mobile', _mobile),
                _field('Email', _email),
                _field('ID / registration number', _id),
                SwitchListTile(
                  title: const Text('Insurance payer'),
                  value: _insurance,
                  onChanged: (v) => setState(() => _insurance = v),
                ),
                if (state.error != null)
                  Text(
                    state.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: state.busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: state.busy ? null : _save,
          child: Text(state.busy ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }
}
