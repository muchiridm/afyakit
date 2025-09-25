// lib/hq/tenants/dialogs/configure_tenant_dialog.dart
import 'dart:convert';
import 'package:flutter/material.dart';

import 'package:afyakit/hq/tenants/models/tenant_model.dart';
import 'package:afyakit/hq/tenants/models/domain_binding.dart';
import 'package:afyakit/hq/tenants/models/tenant_payloads.dart';
import 'package:afyakit/hq/tenants/extensions/tenant_status_x.dart';

class ConfigureTenantDialog extends StatefulWidget {
  const ConfigureTenantDialog({
    super.key,
    required this.tenant,
    required this.domains,
  });

  final Tenant tenant;
  final List<DomainBinding> domains;

  @override
  State<ConfigureTenantDialog> createState() => _ConfigureTenantDialogState();
}

class _ConfigureTenantDialogState extends State<ConfigureTenantDialog>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);

  // General
  late final _name = TextEditingController(text: widget.tenant.displayName);
  late final _primary = TextEditingController(text: widget.tenant.primaryColor);
  late final _logo = TextEditingController(text: widget.tenant.logoPath ?? '');
  final _flags = TextEditingController();

  // Status
  TenantStatus? _chosenStatus;

  // Owner
  final _ownerTarget = TextEditingController();

  // Domains (staged ops, UI-only)
  final _domainInput = TextEditingController();
  final List<DomainOp> _staged = [];

  @override
  void dispose() {
    _tabs.dispose();
    _name.dispose();
    _primary.dispose();
    _logo.dispose();
    _flags.dispose();
    _ownerTarget.dispose();
    _domainInput.dispose();
    super.dispose();
  }

  void _stage(DomainOp op) {
    setState(() => _staged.add(op));
  }

  void _removeStaged(int i) => setState(() => _staged.removeAt(i));

  void _submit() {
    // Build EditTenantPayload (only include changed fields)
    EditTenantPayload? edit;
    String? name = _name.text.trim();
    String? color = _primary.text.trim();
    String? logo = _logo.text.trim();

    if (name.isEmpty) name = null;
    if (color.isEmpty) color = null;
    if (logo.isEmpty) logo = null;

    Map<String, dynamic>? flags;
    if (_flags.text.trim().isNotEmpty) {
      try {
        final j = jsonDecode(_flags.text);
        if (j is Map<String, dynamic>) {
          flags = j;
        }
      } catch (_) {
        /* invalid → ignore; dialog should have warned via UI */
      }
    }

    if (name != null || color != null || logo != null || flags != null) {
      edit = EditTenantPayload(
        displayName: name,
        primaryColor: color,
        logoPath: logo,
        flags: flags,
      );
    }

    final result = ConfigureTenantResult(
      edit: edit,
      setStatus: _chosenStatus,
      transferOwnerTarget: _ownerTarget.text.trim().isEmpty
          ? null
          : _ownerTarget.text.trim(),
      domainOps: List.unmodifiable(_staged),
    );

    Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      clipBehavior: Clip.antiAlias,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.all(16),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760, maxHeight: 640),
        child: Scaffold(
          appBar: AppBar(
            title: Text('Configure • ${widget.tenant.slug}'),
            automaticallyImplyLeading: false,
            bottom: TabBar(
              controller: _tabs,
              tabs: const [
                Tab(text: 'General'),
                Tab(text: 'Status'),
                Tab(text: 'Owner'),
                Tab(text: 'Domains'),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabs,
            children: [
              _generalTab(context),
              _statusTab(context),
              _ownerTab(context),
              _domainsTab(context),
            ],
          ),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                const Spacer(),
                FilledButton.icon(
                  icon: const Icon(Icons.done_all),
                  label: const Text('Apply'),
                  onPressed: _submit,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ── Tabs ─────────────────────────────────────────────────────

  Widget _generalTab(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      TextField(
        controller: _name,
        decoration: const InputDecoration(labelText: 'Display name'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _primary,
        decoration: const InputDecoration(labelText: 'Primary color (#HEX)'),
      ),
      const SizedBox(height: 12),
      TextField(
        controller: _logo,
        decoration: const InputDecoration(labelText: 'Logo path'),
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        title: const Text('Advanced flags (JSON)'),
        childrenPadding: const EdgeInsets.all(8),
        children: [
          TextField(
            controller: _flags,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: '{ "key": "value" }',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Leave blank to keep flags unchanged.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ],
  );

  Widget _statusTab(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SegmentedButton<TenantStatus>(
          segments: const [
            ButtonSegment(value: TenantStatus.active, label: Text('Active')),
            ButtonSegment(
              value: TenantStatus.suspended,
              label: Text('Suspended'),
            ),
            ButtonSegment(value: TenantStatus.deleted, label: Text('Deleted')),
          ],
          selected: {_chosenStatus ?? widget.tenant.status},
          onSelectionChanged: (s) => setState(() => _chosenStatus = s.first),
        ),
        const SizedBox(height: 12),
        Text(
          'If left unchanged, status won’t be updated.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _ownerTab(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        ListTile(
          leading: const Icon(Icons.verified_user),
          title: Text(
            widget.tenant.ownerEmail ?? widget.tenant.ownerUid ?? '—',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: const Text('Current Owner'),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: _ownerTarget,
          decoration: const InputDecoration(
            labelText: 'New owner (email or UID)',
            border: OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Leave empty to keep owner unchanged.',
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );

  Widget _domainsTab(BuildContext context) => Padding(
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _domainInput,
                decoration: const InputDecoration(
                  labelText: 'Add domain (e.g. acme.health)',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: () {
                final d = _domainInput.text.trim();
                if (d.isEmpty) return;
                _stage(DomainOp(DomainAction.add, d));
                _domainInput.clear();
              },
              child: const Text('Stage Add'),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Align(
          alignment: Alignment.centerLeft,
          child: Text(
            'Existing domains',
            style: Theme.of(context).textTheme.titleSmall,
          ),
        ),
        const SizedBox(height: 6),
        Expanded(
          child: ListView.separated(
            itemCount: widget.domains.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final d = widget.domains[i];
              return ListTile(
                title: Text(d.domain),
                subtitle: Wrap(
                  spacing: 8,
                  children: [
                    Chip(
                      label: Text(d.verified ? 'Verified' : 'Unverified'),
                      avatar: Icon(
                        d.verified ? Icons.verified : Icons.hourglass_bottom,
                        size: 18,
                      ),
                    ),
                    if (d.primary)
                      const Chip(
                        label: Text('Primary'),
                        avatar: Icon(Icons.star, size: 18),
                      ),
                    if (d.dnsToken != null && !d.verified)
                      Chip(
                        label: Text('TXT: ${d.dnsToken}'),
                        avatar: const Icon(Icons.key, size: 18),
                      ),
                  ],
                ),
                trailing: Wrap(
                  children: [
                    IconButton(
                      tooltip: 'Stage verify',
                      icon: const Icon(Icons.verified_outlined),
                      onPressed: d.verified
                          ? null
                          : () =>
                                _stage(DomainOp(DomainAction.verify, d.domain)),
                    ),
                    IconButton(
                      tooltip: 'Stage primary',
                      icon: const Icon(Icons.star),
                      onPressed: d.primary
                          ? null
                          : () => _stage(
                              DomainOp(DomainAction.makePrimary, d.domain),
                            ),
                    ),
                    IconButton(
                      tooltip: 'Stage remove',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () =>
                          _stage(DomainOp(DomainAction.remove, d.domain)),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        if (_staged.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (int i = 0; i < _staged.length; i++)
                  InputChip(
                    onDeleted: () => _removeStaged(i),
                    label: Text(
                      '${_staged[i].action.name} ${_staged[i].domain}',
                    ),
                  ),
              ],
            ),
          ),
      ],
    ),
  );
}
