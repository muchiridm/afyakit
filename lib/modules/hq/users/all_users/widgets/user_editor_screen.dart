// lib/hq/users/all_users/widgets/user_editor_screen.dart

import 'package:afyakit/modules/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/modules/hq/users/all_users/all_users_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserEditorScreen extends ConsumerStatefulWidget {
  const UserEditorScreen({super.key, this.initialUser});

  final AllUser? initialUser;

  @override
  ConsumerState<UserEditorScreen> createState() => _UserEditorScreenState();
}

class _UserEditorScreenState extends ConsumerState<UserEditorScreen> {
  late final TextEditingController _phoneCtl;
  late final TextEditingController _nameCtl;

  bool _disabled = false;
  bool _saving = false;
  bool _deleting = false;
  bool _loadingMemberships = false;

  bool get _isNew => widget.initialUser == null;
  String? get _uid => widget.initialUser?.id;

  @override
  void initState() {
    super.initState();
    final u = widget.initialUser;
    _phoneCtl = TextEditingController(text: u?.phoneNumber ?? '');
    _nameCtl = TextEditingController(text: u?.displayName ?? '');
    _disabled = u?.disabled ?? false;

    if (u != null) {
      _fetchMemberships();
    }
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _nameCtl.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  // Build
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final title = _isNew ? 'Create user' : 'Edit user';

    final state = ref.watch(allUsersControllerProvider);
    final mems = _uid != null ? state.membershipsByUid[_uid!] : null;

    return Scaffold(
      appBar: _buildAppBar(title),
      body: _buildBody(context, mems),
      bottomNavigationBar: _buildBottomBar(),
    );
  }

  // ─────────────────────────────────────────────
  // UI helpers
  // ─────────────────────────────────────────────

  AppBar _buildAppBar(String title) {
    return AppBar(
      title: Text(title),
      actions: [
        if (!_isNew)
          IconButton(
            tooltip: 'Delete user',
            icon: const Icon(Icons.delete_outline),
            onPressed: _deleting ? null : _delete,
          ),
      ],
    );
  }

  Widget _buildBody(
    BuildContext context,
    Map<String, Map<String, Object?>>? mems,
  ) {
    return AbsorbPointer(
      absorbing: _saving || _deleting,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (!_isNew) _buildUidSection(context),
          _buildPhoneField(),
          const SizedBox(height: 16),
          _buildNameField(),
          const SizedBox(height: 16),
          if (!_isNew) _buildDisabledSwitch(),
          if (!_isNew) const SizedBox(height: 24),
          if (!_isNew) _buildDirectoryMeta(context),
          if (!_isNew) const SizedBox(height: 24),
          if (!_isNew) _buildMembershipsCard(context, mems),
        ],
      ),
    );
  }

  Widget _buildBottomBar() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: (_saving || _deleting) ? null : _save,
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ),
      ),
    );
  }

  // ── Sections ──────────────────────────────────────────────────

  Widget _buildUidSection(BuildContext context) {
    final uid = _uid!;
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('UID', style: textTheme.labelSmall),
          const SizedBox(height: 4),
          SelectableText(
            uid,
            style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildPhoneField() {
    return TextFormField(
      controller: _phoneCtl,
      decoration: const InputDecoration(
        labelText: 'Phone number (E.164)',
        hintText: '+2547…',
        border: OutlineInputBorder(),
      ),
      keyboardType: TextInputType.phone,
    );
  }

  Widget _buildNameField() {
    return TextFormField(
      controller: _nameCtl,
      decoration: const InputDecoration(
        labelText: 'Display name',
        border: OutlineInputBorder(),
      ),
    );
  }

  Widget _buildDisabledSwitch() {
    return SwitchListTile(
      contentPadding: EdgeInsets.zero,
      title: const Text('Disabled'),
      subtitle: const Text(
        'If disabled, user cannot log in even if they have memberships.',
      ),
      value: _disabled,
      onChanged: (v) {
        setState(() => _disabled = v);
      },
    );
  }

  Widget _buildDirectoryMeta(BuildContext context) {
    final u = widget.initialUser!;
    final created = u.createdAt;
    final lastLogin = u.lastLoginAt;

    final textTheme = Theme.of(context).textTheme;

    String fmt(DateTime dt) => dt.toLocal().toString(); // tweak if needed

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: textTheme.bodySmall!.copyWith(color: Colors.grey.shade700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Directory metadata', style: textTheme.titleSmall),
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(Icons.person_outline, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    u.authExists
                        ? 'Auth user exists'
                        : 'No Firebase Auth user (zombie)',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              if (created != null)
                Row(
                  children: [
                    const Icon(Icons.calendar_today, size: 14),
                    const SizedBox(width: 6),
                    Text('Created: ${fmt(created)}'),
                  ],
                ),
              if (lastLogin != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    const Icon(Icons.login, size: 14),
                    const SizedBox(width: 6),
                    Text('Last login: ${fmt(lastLogin)}'),
                  ],
                ),
              ],
              const SizedBox(height: 4),
              if (u.tenantCount > 0)
                Row(
                  children: [
                    const Icon(Icons.layers, size: 14),
                    const SizedBox(width: 6),
                    Text('Known tenants: ${u.tenantCount}'),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMembershipsCard(
    BuildContext context,
    Map<String, Map<String, Object?>>? mems,
  ) {
    final textTheme = Theme.of(context).textTheme;

    // Always use a mutable list (fixes UnsupportedError: sort)
    final List<MapEntry<String, Map<String, Object?>>> entries = mems != null
        ? List<MapEntry<String, Map<String, Object?>>>.from(mems.entries)
        : <MapEntry<String, Map<String, Object?>>>[];

    entries.sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildMembershipsHeader(),
            const SizedBox(height: 8),
            if (_loadingMemberships && entries.isEmpty)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(8),
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              )
            else if (entries.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(
                  'No tenants yet.',
                  style: textTheme.bodySmall?.copyWith(
                    color: Colors.grey.shade700,
                  ),
                ),
              )
            else
              Column(
                children: entries
                    .map(
                      (e) => _buildMembershipRow(
                        tenantId: e.key,
                        role: (e.value['role'] as String?) ?? '—',
                        active: e.value['active'] == true,
                        email: e.value['email'] as String?,
                      ),
                    )
                    .toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembershipsHeader() {
    return Row(
      children: [
        const Text('Tenant memberships'),
        const Spacer(),
        IconButton(
          tooltip: 'Refresh',
          icon: _loadingMemberships
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.refresh, size: 18),
          onPressed: _loadingMemberships ? null : _fetchMemberships,
        ),
        const SizedBox(width: 4),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          ),
          icon: const Icon(Icons.add, size: 18),
          label: const Text('Add'),
          onPressed: _addMembershipDialog,
        ),
      ],
    );
  }

  Widget _buildMembershipRow({
    required String tenantId,
    required String role,
    required bool active,
    String? email,
  }) {
    final subtitle = (email == null || email.trim().isEmpty)
        ? 'Role: $role'
        : 'Role: $role · $email';

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(
        tenantId,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(subtitle),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            size: 18,
            color: active ? Colors.green : Colors.orangeAccent,
          ),
          IconButton(
            tooltip: 'Edit',
            icon: const Icon(Icons.edit, size: 18),
            onPressed: () => _editMembershipDialog(
              tenantId: tenantId,
              currentRole: role,
              currentActive: active,
              currentEmail: email,
            ),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  // Actions (save/delete/memberships)
  // ─────────────────────────────────────────────

  Future<void> _fetchMemberships() async {
    final uid = _uid;
    if (uid == null) return;
    setState(() => _loadingMemberships = true);
    final ctrl = ref.read(allUsersControllerProvider.notifier);
    try {
      await ctrl.fetchMemberships(uid);
    } finally {
      if (mounted) {
        setState(() => _loadingMemberships = false);
      }
    }
  }

  Future<void> _save() async {
    final phone = _phoneCtl.text.trim();
    final name = _nameCtl.text.trim();

    if (phone.isEmpty) {
      SnackService.showError('Phone number is required');
      return;
    }

    setState(() => _saving = true);

    final ctrl = ref.read(allUsersControllerProvider.notifier);

    try {
      if (_isNew) {
        await ctrl.createUser(
          phoneNumber: phone,
          displayName: name.isEmpty ? null : name,
        );
      } else {
        final uid = _uid!;
        await ctrl.updateUser(
          uid: uid,
          phoneNumber: phone,
          displayName: name,
          disabled: _disabled,
        );
      }

      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final uid = _uid;
    if (uid == null) return;

    final sure =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete user'),
            content: const Text(
              'This will delete the Firebase Auth user and mark the '
              'directory row as deleted. Continue?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!sure) return;

    setState(() => _deleting = true);

    final ctrl = ref.read(allUsersControllerProvider.notifier);

    try {
      await ctrl.deleteUser(uid);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  // ─────────────────────────────────────────────
  // Membership dialogs
  // ─────────────────────────────────────────────

  Future<void> _addMembershipDialog() async {
    final uid = _uid;
    if (uid == null) return;

    final tenantCtl = TextEditingController();
    final roleCtl = TextEditingController(text: 'staff');
    final emailCtl = TextEditingController();
    bool active = true;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: const Text('Add tenant membership'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: tenantCtl,
                      decoration: const InputDecoration(
                        labelText: 'Tenant ID',
                        hintText: 'e.g. afyakit, danabtmc',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: roleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Role (e.g. admin, staff)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtl,
                      decoration: const InputDecoration(
                        labelText: 'Tenant email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final tenantId = tenantCtl.text.trim();
                      if (tenantId.isEmpty) return;
                      final role = roleCtl.text.trim().isEmpty
                          ? 'staff'
                          : roleCtl.text.trim();
                      final email = emailCtl.text.trim().isEmpty
                          ? null
                          : emailCtl.text.trim();

                      final ctrl = ref.read(
                        allUsersControllerProvider.notifier,
                      );
                      await ctrl.updateMembership(
                        uid,
                        tenantId,
                        role: role,
                        active: active,
                        email: email,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    tenantCtl.dispose();
    roleCtl.dispose();
    emailCtl.dispose();

    if (confirmed) {
      await _fetchMemberships();
    }
  }

  Future<void> _editMembershipDialog({
    required String tenantId,
    required String currentRole,
    required bool currentActive,
    String? currentEmail,
  }) async {
    final uid = _uid;
    if (uid == null) return;

    final roleCtl = TextEditingController(
      text: currentRole == '—' ? '' : currentRole,
    );
    final emailCtl = TextEditingController(text: currentEmail ?? '');
    bool active = currentActive;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => StatefulBuilder(
            builder: (ctx, setState) {
              return AlertDialog(
                title: Text('Manage $tenantId'),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextFormField(
                      controller: roleCtl,
                      decoration: const InputDecoration(
                        labelText: 'Role (e.g. admin, staff)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: emailCtl,
                      decoration: const InputDecoration(
                        labelText: 'Tenant email',
                        border: OutlineInputBorder(),
                      ),
                      keyboardType: TextInputType.emailAddress,
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Active'),
                      value: active,
                      onChanged: (v) => setState(() => active = v),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    onPressed: () async {
                      final sure = await _confirmRemoveMembership(
                        ctx,
                        tenantId,
                      );
                      if (sure == true) {
                        final ctrl = ref.read(
                          allUsersControllerProvider.notifier,
                        );
                        await ctrl.removeMembership(uid, tenantId);
                        if (ctx.mounted) Navigator.of(ctx).pop(true);
                      }
                    },
                    child: const Text('Remove access'),
                  ),
                  FilledButton(
                    onPressed: () async {
                      final role = roleCtl.text.trim().isEmpty
                          ? 'staff'
                          : roleCtl.text.trim();
                      final email = emailCtl.text.trim().isEmpty
                          ? null
                          : emailCtl.text.trim();

                      final ctrl = ref.read(
                        allUsersControllerProvider.notifier,
                      );
                      await ctrl.updateMembership(
                        uid,
                        tenantId,
                        role: role,
                        active: active,
                        email: email,
                      );
                      if (ctx.mounted) Navigator.of(ctx).pop(true);
                    },
                    child: const Text('Save'),
                  ),
                ],
              );
            },
          ),
        ) ??
        false;

    roleCtl.dispose();
    emailCtl.dispose();

    if (confirmed) {
      await _fetchMemberships();
    }
  }

  Future<bool?> _confirmRemoveMembership(BuildContext ctx, String tenantId) {
    return showDialog<bool>(
      context: ctx,
      builder: (c) => AlertDialog(
        title: const Text('Remove access'),
        content: Text('Remove this user\'s access to "$tenantId"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(c).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.of(c).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
  }
}
