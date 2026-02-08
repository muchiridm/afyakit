import 'package:afyakit/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/hq/users/all_users/controllers/user_editor_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserEditorScreen extends ConsumerWidget {
  const UserEditorScreen({
    super.key,
    required this.targetTenantId,
    required this.userUid,
    this.initialUser,
  });

  final String targetTenantId;
  final String userUid;
  final AllUser? initialUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = UserEditorArgs(
      targetTenantId: targetTenantId,
      uid: userUid,
      initialUser: initialUser,
    );

    final state = ref.watch(userEditorControllerProvider(args));
    final ctrl = ref.read(userEditorControllerProvider(args).notifier);

    final busy = state.saving || state.deleting;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit tenant access'),
        actions: [
          IconButton(
            tooltip: 'Remove access',
            icon: const Icon(Icons.person_remove_alt_1),
            onPressed: busy
                ? null
                : () async {
                    final sure =
                        await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Remove tenant access'),
                            content: Text(
                              'Remove this user\'s access to "${state.targetTenantId}"?',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(ctx).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () => Navigator.of(ctx).pop(true),
                                child: const Text('Remove'),
                              ),
                            ],
                          ),
                        ) ??
                        false;

                    if (!sure) return;

                    final ok = await ctrl.removeAccess();
                    if (ok && context.mounted) Navigator.of(context).pop(true);
                  },
          ),
        ],
      ),
      body: AbsorbPointer(
        absorbing: busy,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _TargetTenantCard(
              tenantId: state.targetTenantId,
              hasAccess: state.hasAccess,
            ),
            const SizedBox(height: 16),
            _UidSection(uid: state.uid),
            const SizedBox(height: 16),
            _AccessLevelPicker(
              value: state.level,
              onChanged: ctrl.setAccessLevel,
            ),
            const SizedBox(height: 12),
            _PatchPreviewCard(
              type: ctrl.patchTypePreview,
              roles: ctrl.patchRolesPreview,
            ),
            const SizedBox(height: 12),
            _TenantEmailReadOnly(email: state.tenantEmail),
            const SizedBox(height: 12),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Active'),
              subtitle: const Text(
                'If inactive, user is in the tenant but blocked.',
              ),
              value: state.active,
              onChanged: ctrl.setActive,
            ),
            const SizedBox(height: 24),
            _MembershipsCard(
              loading: state.loadingMemberships,
              memberships: state.allMemberships,
              targetTenantId: state.targetTenantId,
              onRefresh: () => ctrl.refreshMemberships(force: true),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: busy
                  ? null
                  : () async {
                      final ok = await ctrl.save();
                      if (!ok) {
                        SnackService.showError('❌ Save failed');
                        return;
                      }
                      if (context.mounted) Navigator.of(context).pop(true);
                    },
              child: Text(state.saving ? 'Saving…' : 'Save'),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Dumb UI widgets (pure rendering)
// ─────────────────────────────────────────────

class _TargetTenantCard extends StatelessWidget {
  const _TargetTenantCard({required this.tenantId, required this.hasAccess});

  final String tenantId;
  final bool hasAccess;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.apartment_outlined),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Target tenant'),
                  const SizedBox(height: 4),
                  Text(
                    tenantId,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    hasAccess ? 'Access exists.' : 'No access yet.',
                    style: TextStyle(color: Colors.grey.shade700),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UidSection extends StatelessWidget {
  const _UidSection({required this.uid});
  final String uid;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User UID', style: textTheme.labelSmall),
        const SizedBox(height: 4),
        SelectableText(
          uid,
          style: textTheme.bodyMedium?.copyWith(color: Colors.grey.shade700),
        ),
        const SizedBox(height: 6),
        Text(
          'User uid (read-only)',
          style: textTheme.bodySmall?.copyWith(color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _AccessLevelPicker extends StatelessWidget {
  const _AccessLevelPicker({required this.value, required this.onChanged});

  final AccessLevel value;
  final ValueChanged<AccessLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Access level',
        border: OutlineInputBorder(),
        helperText:
            'Maps to backend fields: type = member|staff and staffRoles = [] or [role].',
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<AccessLevel>(
          isExpanded: true,
          value: value,
          items: AccessLevel.values
              .map((e) => DropdownMenuItem(value: e, child: Text(e.label)))
              .toList(),
          onChanged: (v) {
            if (v == null) return;
            onChanged(v);
          },
        ),
      ),
    );
  }
}

class _PatchPreviewCard extends StatelessWidget {
  const _PatchPreviewCard({required this.type, required this.roles});

  final String type;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    final rolesText = roles.isEmpty ? '[]' : roles.toString();

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: DefaultTextStyle(
          style: TextStyle(color: Colors.grey.shade800),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Backend patch preview',
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              Text('type: $type'),
              Text('staffRoles: $rolesText'),
              const SizedBox(height: 6),
              Text(
                type == 'member'
                    ? 'Member = no staff privileges.'
                    : (roles.isEmpty
                          ? 'Staff = staff privileges, no specific role.'
                          : 'Staff with role = ${roles.first}.'),
                style: TextStyle(color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TenantEmailReadOnly extends StatelessWidget {
  const _TenantEmailReadOnly({required this.email});
  final String? email;

  @override
  Widget build(BuildContext context) {
    final v = (email ?? '').trim();
    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Tenant email (optional)',
        border: OutlineInputBorder(),
        helperText:
            'Read-only (backend PatchAuthUserSchema does not accept email).',
      ),
      child: Text(v.isEmpty ? '—' : v),
    );
  }
}

class _MembershipsCard extends StatelessWidget {
  const _MembershipsCard({
    required this.loading,
    required this.memberships,
    required this.targetTenantId,
    required this.onRefresh,
  });

  final bool loading;
  final Map<String, Map<String, Object?>>? memberships;
  final String targetTenantId;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    final entries = memberships != null
        ? List<MapEntry<String, Map<String, Object?>>>.from(
            memberships!.entries,
          )
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
            Row(
              children: [
                const Text('Directory memberships'),
                const Spacer(),
                IconButton(
                  tooltip: 'Refresh',
                  icon: loading
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh, size: 18),
                  onPressed: loading ? null : onRefresh,
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (loading && entries.isEmpty)
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
                children: entries.map((e) {
                  final role = (e.value['role'] as String?) ?? '—';
                  final active = e.value['active'] == true;
                  final email = (e.value['email'] as String?)?.trim();

                  final subtitle = (email == null || email.isEmpty)
                      ? 'Role: $role'
                      : 'Role: $role · $email';

                  final isTarget = e.key == targetTenantId;

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      e.key,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        color: isTarget ? Colors.blueGrey.shade900 : null,
                      ),
                    ),
                    subtitle: Text(subtitle),
                    trailing: Icon(
                      active ? Icons.check_circle : Icons.cancel,
                      size: 18,
                      color: active ? Colors.green : Colors.orangeAccent,
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }
}
