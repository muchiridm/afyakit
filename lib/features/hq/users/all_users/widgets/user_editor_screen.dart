// lib/features/hq/users/all_users/widgets/user_editor_screen.dart
import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/controllers/user_editor_controller.dart';
import 'package:afyakit/features/hq/users/all_users/widgets/app_email_change_dialog.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class UserEditorScreen extends ConsumerWidget {
  const UserEditorScreen({
    super.key,
    required this.tenantId,
    required this.userUid,
    this.initialUser,
    this.initialAppId,
  });

  final String tenantId;
  final String userUid;
  final AllUser? initialUser;
  final String? initialAppId;
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
    final appsProvider = hqAppProfilesProvider(tenantId.trim().toLowerCase());
    final appsAsync = ref.watch(appsProvider);
    final apps = appsAsync.asData?.value ?? const <AppProfile>[];
    final selectedApp = state.appId.trim();
    final selectedRegistered = apps.any(
      (app) => app.id.trim().toLowerCase() == selectedApp && app.active,
    );
    final busy = state.saving || state.deleting;
    final loading = state.loadingMemberships;
    final canEdit =
        !busy &&
        !loading &&
        state.hasAccess &&
        state.tenantAccountActive &&
        selectedRegistered;
    final canRemove = canEdit && state.appMembershipExists;
    final theme = Theme.of(context);
    final appEmail = state.selectedAppEmail?.trim();
    final hasAppEmail = appEmail != null && appEmail.isNotEmpty;
    final emailVerified = hasAppEmail && state.selectedAppEmailVerified;
    final canChangeEmail = canEdit && state.appMembershipExists && state.active;
    Future<void> changeEmail() async {
      if (selectedApp.isEmpty || !selectedRegistered) return;
      final changed = await showAppEmailChangeDialog(
        context: context,
        ref: ref,
        tenantId: state.tenantId,
        appId: selectedApp,
        uid: state.uid,
        currentEmail: hasAppEmail ? appEmail : null,
      );
      if (!changed || !context.mounted) return;
      await ctrl.refreshMemberships(force: true);
    }

    Future<void> disableApp() async {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Disable application access?'),
          content: Text(
            'Disable access to $selectedApp? The tenant account and other '
            'applications will not be affected.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              child: const Text('Disable access'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;
      final success = await ctrl.removeAccess();
      if (success && context.mounted) Navigator.of(context).pop(true);
    }

    Future<void> save() async {
      final success = await ctrl.save();
      if (!success || !context.mounted) return;
      SnackService.showInfo('Application access saved.');
      Navigator.of(context).pop(true);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Manage user')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.business_outlined),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.tenantId,
                          style: theme.textTheme.titleMedium,
                        ),
                      ),
                      Chip(
                        label: Text(
                          !state.hasAccess
                              ? 'No account'
                              : state.tenantAccountActive
                              ? 'Active'
                              : 'Disabled',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Divider(height: 24),
                  Text('User ID', style: theme.textTheme.labelSmall),
                  SelectableText(state.uid, style: theme.textTheme.bodySmall),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('Application access', style: theme.textTheme.titleMedium),
          const SizedBox(height: 12),
          appsAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (error, _) => ListTile(
              leading: const Icon(Icons.error_outline),
              title: const Text('Unable to load applications'),
              subtitle: Text('$error'),
              trailing: IconButton(
                tooltip: 'Retry',
                onPressed: () => ref.invalidate(appsProvider),
                icon: const Icon(Icons.refresh),
              ),
            ),
            data: (loadedApps) {
              final sorted = List<AppProfile>.from(loadedApps)
                ..sort(
                  (a, b) => a.displayName.toLowerCase().compareTo(
                    b.displayName.toLowerCase(),
                  ),
                );
              final selectedExists = sorted.any(
                (app) => app.id.trim().toLowerCase() == selectedApp,
              );
              return DropdownButtonFormField<String>(
                key: ValueKey(selectedApp),
                initialValue: selectedExists && selectedApp.isNotEmpty
                    ? selectedApp
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(
                  labelText: 'Application',
                  border: OutlineInputBorder(),
                ),
                items: sorted.map((app) {
                  final id = app.id.trim().toLowerCase();
                  return DropdownMenuItem<String>(
                    value: id,
                    enabled: app.active,
                    child: Text(
                      app.active
                          ? app.displayName
                          : '${app.displayName} (inactive)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  );
                }).toList(),
                onChanged: busy || loading
                    ? null
                    : (value) {
                        if (value != null) ctrl.setAppId(value);
                      },
              );
            },
          ),
          if (selectedRegistered &&
              state.hasAccess &&
              state.tenantAccountActive) ...[
            const SizedBox(height: 12),
            Card.outlined(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Application email',
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Used only for $selectedApp.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 12),
                    SelectableText(
                      hasAppEmail ? appEmail : 'No email registered',
                      style: theme.textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Icon(
                          emailVerified
                              ? Icons.verified_outlined
                              : Icons.info_outline,
                          size: 18,
                          color: emailVerified
                              ? theme.colorScheme.primary
                              : theme.colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            emailVerified
                                ? 'Verified'
                                : hasAppEmail
                                ? 'Not verified'
                                : 'Not configured',
                            style: theme.textTheme.bodySmall,
                          ),
                        ),
                        OutlinedButton.icon(
                          onPressed: canChangeEmail ? changeEmail : null,
                          icon: Icon(
                            hasAppEmail ? Icons.edit_outlined : Icons.add,
                          ),
                          label: Text(hasAppEmail ? 'Change' : 'Add email'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (loading) const LinearProgressIndicator(),
          if (!loading && !state.hasAccess)
            const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('No tenant account'),
              subtitle: Text('Create tenant access before assigning an app.'),
            )
          else if (!loading && !state.tenantAccountActive)
            const ListTile(
              leading: Icon(Icons.lock_outline),
              title: Text('Tenant account disabled'),
              subtitle: Text(
                'Enable the tenant account before editing access.',
              ),
            )
          else if (selectedApp.isEmpty)
            const Text('Select an application to edit its access.')
          else if (!selectedRegistered && !appsAsync.isLoading)
            const Text('This application is unavailable or inactive.')
          else if (selectedRegistered) ...[
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow access'),
              subtitle: Text(selectedApp),
              value: state.active,
              onChanged: canEdit ? ctrl.setActive : null,
            ),
            const SizedBox(height: 8),
            Text('Role', style: theme.textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: AccessLevel.values
                  .map(
                    (level) => ChoiceChip(
                      label: Text(level.label),
                      selected: state.level == level,
                      onSelected: canEdit && state.active
                          ? (_) => ctrl.setAccessLevel(level)
                          : null,
                    ),
                  )
                  .toList(),
            ),
            if (canRemove) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: disableApp,
                icon: const Icon(Icons.person_remove_alt_1),
                label: const Text('Disable this application access'),
              ),
            ],
          ],
          const SizedBox(height: 16),
          ExpansionTile(
            title: const Text('Existing memberships'),
            subtitle: Text('${state.allMemberships.length} tenant(s)'),
            trailing: loading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.expand_more),
            children: [
              if (state.allMemberships.isEmpty)
                const ListTile(title: Text('No memberships found')),
              ...state.allMemberships.entries.map((entry) {
                final membership = entry.value;
                final appIds = <String>{
                  ...membership.appMembershipsByApp.keys,
                  ...membership.staffRolesByApp.keys,
                }.toList()..sort();
                return ListTile(
                  title: Text(entry.key),
                  subtitle: Text(
                    '${membership.active ? 'Active' : 'Disabled'}'
                    '${appIds.isEmpty ? '' : ' · Apps: ${appIds.join(', ')}'}',
                  ),
                );
              }),
              TextButton.icon(
                onPressed: loading
                    ? null
                    : () => ctrl.refreshMemberships(force: true),
                icon: const Icon(Icons.refresh),
                label: const Text('Refresh'),
              ),
            ],
          ),
          const SizedBox(height: 80),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
          child: FilledButton.icon(
            onPressed: canEdit ? save : null,
            icon: busy
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(busy ? 'Saving…' : 'Save application access'),
          ),
        ),
      ),
    );
  }
}
