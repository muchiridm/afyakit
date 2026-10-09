// lib/features/hq/users/all_users/widgets/user_editor_screen.dart

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/controllers/user_editor_controller.dart';
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserEditorScreen extends ConsumerWidget {
  const UserEditorScreen({
    super.key,
    required this.tenantId,
    required this.userUid,
    this.initialUser,
  });

  final String tenantId;
  final String userUid;
  final AllUser? initialUser;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final args = UserEditorArgs(
      tenantId: tenantId,
      uid: userUid,
      initialUser: initialUser,
    );

    final provider = userEditorControllerProvider(args);
    final state = ref.watch(provider);
    final ctrl = ref.read(provider.notifier);

    final appsAsync = ref.watch(
      hqAppProfilesProvider(tenantId.trim().toLowerCase()),
    );

    final busy = state.saving || state.deleting;
    final loading = state.loadingMemberships;
    final selectedApp = state.appId.trim();

    final apps = appsAsync.asData?.value;
    final selectedIsRegistered =
        apps?.any(
          (app) => app.id.trim().toLowerCase() == selectedApp && app.active,
        ) ??
        false;

    final canEdit =
        !busy &&
        !loading &&
        state.hasAccess &&
        state.tenantAccountActive &&
        selectedIsRegistered;

    final canSave = canEdit;
    final canRemove = canEdit && state.appMembershipExists;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit application access'),
        actions: [
          IconButton(
            tooltip: 'Disable selected app access',
            icon: const Icon(Icons.person_remove_alt_1),
            onPressed: !canRemove
                ? null
                : () async {
                    final confirmed =
                        await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Disable application access?'),
                            content: Text(
                              'Disable this user\'s access to '
                              '"${state.appId}"?\n\n'
                              'Only this application will be affected. '
                              'The tenant account and access to other '
                              'applications will remain unchanged.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red,
                                ),
                                onPressed: () =>
                                    Navigator.of(dialogContext).pop(true),
                                child: const Text('Disable access'),
                              ),
                            ],
                          ),
                        ) ??
                        false;

                    if (!confirmed) return;

                    final success = await ctrl.removeAccess();

                    if (success && context.mounted) {
                      Navigator.of(context).pop(true);
                    }
                  },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _TenantCard(
            tenantId: state.tenantId,
            hasAccess: state.hasAccess,
            active: state.tenantAccountActive,
          ),
          const SizedBox(height: 16),

          _UidSection(uid: state.uid),
          const SizedBox(height: 16),

          _AppSelector(
            appsAsync: appsAsync,
            selectedAppId: selectedApp,
            enabled: !busy && !loading,
            onChanged: ctrl.setAppId,
            onRefresh: () => ref.invalidate(
              hqAppProfilesProvider(tenantId.trim().toLowerCase()),
            ),
          ),
          const SizedBox(height: 16),

          if (!state.hasAccess && !loading)
            const _NoticeCard(
              icon: Icons.warning_amber_outlined,
              message:
                  'This user does not have a tenant account. '
                  'Application access cannot be assigned yet.',
            ),

          if (state.hasAccess && !state.tenantAccountActive && !loading)
            const _NoticeCard(
              icon: Icons.lock_outline,
              message:
                  'The tenant account is disabled. '
                  'Enable the tenant account before assigning '
                  'application access.',
            ),

          if (selectedApp.isEmpty)
            const _NoticeCard(
              icon: Icons.apps_outlined,
              message:
                  'Select an application to view and edit '
                  'its membership and staff roles.',
            )
          else if (selectedIsRegistered) ...[
            _ApplicationAccessCard(
              appId: selectedApp,
              enabled: canEdit,
              membershipActive: state.active,
              membershipExists: state.appMembershipExists,
              role: state.level,
              onMembershipChanged: ctrl.setActive,
              onRoleChanged: ctrl.setAccessLevel,
            ),
            const SizedBox(height: 12),

            _AccessPreviewCard(
              appId: selectedApp,
              active: state.active,
              roles: ctrl.patchRolesPreview,
            ),
          ] else
            const _NoticeCard(
              icon: Icons.error_outline,
              message:
                  'The selected application is unavailable '
                  'or inactive. Select an active application.',
            ),

          const SizedBox(height: 16),

          _TenantEmailReadOnly(email: state.tenantEmail),
          const SizedBox(height: 24),

          _MembershipsCard(
            loading: loading,
            memberships: state.allMemberships,
            tenantId: state.tenantId,
            apps: apps ?? const <AppProfile>[],
            onRefresh: () {
              // ignore: discarded_futures
              ctrl.refreshMemberships(force: true);
            },
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: FilledButton.icon(
            onPressed: !canSave
                ? null
                : () async {
                    final success = await ctrl.save();

                    if (!success) return;

                    if (context.mounted) {
                      SnackService.showInfo('Application access saved.');
                      Navigator.of(context).pop(true);
                    }
                  },
            icon: busy
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(
              state.saving
                  ? 'Saving…'
                  : state.deleting
                  ? 'Updating…'
                  : 'Save application access',
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Tenant summary
// ─────────────────────────────────────────────

class _TenantCard extends StatelessWidget {
  const _TenantCard({
    required this.tenantId,
    required this.hasAccess,
    required this.active,
  });

  final String tenantId;
  final bool hasAccess;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            const Icon(Icons.apartment_outlined),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Tenant'),
                  const SizedBox(height: 4),
                  Text(
                    tenantId,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    !hasAccess
                        ? 'No tenant account'
                        : active
                        ? 'Tenant account active'
                        : 'Tenant account disabled',
                    style: TextStyle(
                      color: active
                          ? Colors.green.shade700
                          : Colors.orange.shade800,
                    ),
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

// ─────────────────────────────────────────────
// User UID
// ─────────────────────────────────────────────

class _UidSection extends StatelessWidget {
  const _UidSection({required this.uid});

  final String uid;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('User UID', style: theme.labelSmall),
        const SizedBox(height: 4),
        SelectableText(uid, style: theme.bodyMedium),
        const SizedBox(height: 4),
        Text('Read-only Firebase user identifier.', style: theme.bodySmall),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Registered application selector
// ─────────────────────────────────────────────

class _AppSelector extends StatelessWidget {
  const _AppSelector({
    required this.appsAsync,
    required this.selectedAppId,
    required this.enabled,
    required this.onChanged,
    required this.onRefresh,
  });

  final AsyncValue<List<AppProfile>> appsAsync;
  final String selectedAppId;
  final bool enabled;
  final ValueChanged<String> onChanged;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    return appsAsync.when(
      loading: () => const InputDecorator(
        decoration: InputDecoration(
          labelText: 'Application',
          border: OutlineInputBorder(),
        ),
        child: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text('Loading applications…'),
          ],
        ),
      ),
      error: (error, _) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            children: [
              const Icon(Icons.error_outline),
              const SizedBox(width: 12),
              Expanded(child: Text('Failed to load applications: $error')),
              TextButton(onPressed: onRefresh, child: const Text('Retry')),
            ],
          ),
        ),
      ),
      data: (apps) {
        final sorted = List<AppProfile>.from(apps)
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

        final selectedExists = sorted.any(
          (app) => app.id.trim().toLowerCase() == selectedAppId,
        );

        return DropdownButtonFormField<String>(
          key: ValueKey(selectedAppId),
          initialValue: selectedExists && selectedAppId.isNotEmpty
              ? selectedAppId
              : null,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'Application',
            helperText:
                'Select the application whose access you want to manage.',
            border: OutlineInputBorder(),
            prefixIcon: Icon(Icons.apps_outlined),
          ),
          hint: const Text('Select application'),
          items: sorted.map((app) {
            final appId = app.id.trim().toLowerCase();

            return DropdownMenuItem<String>(
              value: appId,
              enabled: app.active,
              child: Text(
                app.active
                    ? '${app.displayName} ($appId)'
                    : '${app.displayName} ($appId) — inactive',
                overflow: TextOverflow.ellipsis,
              ),
            );
          }).toList(),
          onChanged: !enabled
              ? null
              : (value) {
                  if (value != null) {
                    onChanged(value);
                  }
                },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Application access editor
// ─────────────────────────────────────────────

class _ApplicationAccessCard extends StatelessWidget {
  const _ApplicationAccessCard({
    required this.appId,
    required this.enabled,
    required this.membershipActive,
    required this.membershipExists,
    required this.role,
    required this.onMembershipChanged,
    required this.onRoleChanged,
  });

  final String appId;
  final bool enabled;
  final bool membershipActive;
  final bool membershipExists;
  final AccessLevel role;
  final ValueChanged<bool> onMembershipChanged;
  final ValueChanged<AccessLevel> onRoleChanged;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Application access — $appId',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              membershipExists
                  ? 'Existing application membership'
                  : 'No application membership assigned yet',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const Divider(height: 24),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Application membership active'),
              subtitle: const Text(
                'Controls access to this application only. '
                'Other applications are unaffected.',
              ),
              value: membershipActive,
              onChanged: enabled ? onMembershipChanged : null,
            ),
            const SizedBox(height: 12),
            InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Application role',
                helperText:
                    'Member has no staff role. Manager, Admin and '
                    'Owner apply only to this application.',
                border: OutlineInputBorder(),
              ),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: AccessLevel.values.map((level) {
                  return ChoiceChip(
                    label: Text(level.label),
                    selected: role == level,
                    onSelected: enabled && membershipActive
                        ? (_) => onRoleChanged(level)
                        : null,
                  );
                }).toList(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Access preview
// ─────────────────────────────────────────────

class _AccessPreviewCard extends StatelessWidget {
  const _AccessPreviewCard({
    required this.appId,
    required this.active,
    required this.roles,
  });

  final String appId;
  final bool active;
  final List<String> roles;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Application access preview',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text('Application: $appId'),
            Text('Membership: ${active ? 'active' : 'disabled'}'),
            Text('Staff roles: ${roles.toString()}'),
            const SizedBox(height: 8),
            Text(
              active
                  ? 'Changes will apply only to $appId.'
                  : 'Disabling membership also clears staff '
                        'roles for $appId.',
              style: TextStyle(color: Colors.grey.shade700),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Read-only email
// ─────────────────────────────────────────────

class _TenantEmailReadOnly extends StatelessWidget {
  const _TenantEmailReadOnly({required this.email});

  final String? email;

  @override
  Widget build(BuildContext context) {
    final value = (email ?? '').trim();

    return InputDecorator(
      decoration: const InputDecoration(
        labelText: 'Tenant email',
        border: OutlineInputBorder(),
        helperText: 'Read-only. Retrieved from the tenant auth-user record.',
      ),
      child: Text(value.isEmpty ? '—' : value),
    );
  }
}

// ─────────────────────────────────────────────
// Notice
// ─────────────────────────────────────────────

class _NoticeCard extends StatelessWidget {
  const _NoticeCard({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(icon),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Existing memberships summary
// ─────────────────────────────────────────────

class _MembershipsCard extends StatelessWidget {
  const _MembershipsCard({
    required this.loading,
    required this.memberships,
    required this.tenantId,
    required this.apps,
    required this.onRefresh,
  });

  final bool loading;
  final Map<String, AllUserMembership> memberships;
  final String tenantId;
  final List<AppProfile> apps;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final entries = memberships.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return Card(
      elevation: 0,
      color: Colors.grey.shade50,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Existing memberships',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh memberships',
                  onPressed: loading ? null : onRefresh,
                  icon: loading
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (entries.isEmpty)
              const Text('No tenant memberships found.')
            else
              ...entries.map((entry) {
                final membership = entry.value;
                final isCurrentTenant = entry.key == tenantId;

                final appIds = <String>{
                  ...membership.appMembershipsByApp.keys,
                  ...membership.staffRolesByApp.keys,
                }.toList()..sort();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: Icon(
                        membership.active
                            ? Icons.check_circle_outline
                            : Icons.block_outlined,
                        color: membership.active ? Colors.green : Colors.orange,
                      ),
                      title: Text(
                        entry.key,
                        style: TextStyle(
                          fontWeight: isCurrentTenant
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                      subtitle: Text(
                        'Tenant account: '
                        '${membership.active ? 'active' : 'disabled'}',
                      ),
                    ),
                    if (appIds.isEmpty)
                      const Padding(
                        padding: EdgeInsets.only(left: 16, bottom: 8),
                        child: Text('No app memberships assigned.'),
                      )
                    else
                      ...appIds.map((appId) {
                        final matchingApps = apps.where(
                          (app) => app.id == appId,
                        );
                        final name = matchingApps.isEmpty
                            ? appId
                            : matchingApps.first.displayName;

                        final active = membership.hasActiveAppMembership(appId);
                        final exists = membership.hasAppMembership(appId);
                        final roles = membership.effectiveRolesForApp(appId);

                        final status = !exists
                            ? 'No membership'
                            : active
                            ? 'Active'
                            : 'Disabled';

                        return Padding(
                          padding: const EdgeInsets.only(left: 16),
                          child: ListTile(
                            dense: true,
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              active
                                  ? Icons.check_circle
                                  : Icons.cancel_outlined,
                              size: 18,
                              color: active ? Colors.green : Colors.grey,
                            ),
                            title: Text('$name ($appId)'),
                            subtitle: Text(
                              '$status · '
                              '${!active
                                  ? 'No effective role'
                                  : roles.isEmpty
                                  ? 'Member'
                                  : roles.join(', ')}',
                            ),
                          ),
                        );
                      }),
                    const Divider(),
                  ],
                );
              }),
          ],
        ),
      ),
    );
  }
}
