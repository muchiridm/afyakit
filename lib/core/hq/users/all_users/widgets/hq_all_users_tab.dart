// lib/hq/users/all_users/widgets/hq_all_users_tab.dart

import 'package:afyakit/core/hq/shell/hq_controller.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/core/hq/tenants/providers/hq_tenants_provider.dart';
import 'package:afyakit/core/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/core/hq/users/all_users/controllers/all_users_controller.dart';
import 'package:afyakit/core/hq/users/all_users/widgets/user_editor_screen.dart';
import 'package:afyakit/core/hq/users/all_users/widgets/user_row_tile.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HqAllUsersTab extends ConsumerStatefulWidget {
  const HqAllUsersTab({super.key});

  @override
  ConsumerState<HqAllUsersTab> createState() => _HqAllUsersTabState();
}

class _HqAllUsersTabState extends ConsumerState<HqAllUsersTab> {
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allUsersControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  Future<bool?> _openEditorUid({
    required String targetTenantId,
    required String uid,
    AllUser? initialUser,
  }) {
    return Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UserEditorScreen(
          targetTenantId: targetTenantId,
          userUid: uid,
          initialUser: initialUser,
        ),
      ),
    );
  }

  Future<void> _openEditor({
    required String targetTenantId,
    required AllUser user,
  }) async {
    final changed = await _openEditorUid(
      targetTenantId: targetTenantId,
      uid: user.id,
      initialUser: user,
    );

    if (changed == true && mounted) {
      await ref.read(allUsersControllerProvider.notifier).refresh();
    }
  }

  Future<void> _createUserFlow(String targetTenantId) async {
    final input = await showCreateTenantUserDialog(context);
    if (input == null) return;

    final ctrl = ref.read(allUsersControllerProvider.notifier);

    final uid = await ctrl.hqCreateTenantUser(
      targetTenantId: targetTenantId,
      phoneNumber: input.phoneNumber,
      displayName: input.displayName,
    );

    if (uid == null || uid.trim().isEmpty) return;

    final createdUid = uid.trim();

    await ctrl.refresh();

    final latest = ref.read(allUsersControllerProvider);
    final maybeUser = _findUserById(latest.items, createdUid);

    if (!mounted) return;

    final changed = await _openEditorUid(
      targetTenantId: targetTenantId,
      uid: createdUid,
      initialUser: maybeUser,
    );

    if (changed == true && mounted) {
      await ctrl.refresh();
    }
  }

  Future<void> _deleteUnassignedUserFlow(AllUser user) async {
    final label = _userLabel(user);

    final sure =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete global user?'),
            content: Text(
              'Delete "$label" permanently?\n\n'
              'This should only be used for users with no tenant access. '
              'Firebase Auth and the global users/{uid} record will be deleted.\n\n'
              'UID:\n${user.id}',
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

    final ctrl = ref.read(allUsersControllerProvider.notifier);
    final ok = await ctrl.hqDeleteGlobalUser(user.id);

    if (!ok) return;

    await ctrl.refresh();
  }

  AllUser? _findUserById(List<AllUser> users, String uid) {
    for (final user in users) {
      if (user.id == uid) return user;
    }

    return null;
  }

  String _userLabel(AllUser user) {
    final name = (user.displayName ?? '').trim();
    if (name.isNotEmpty) return name;

    final phone = (user.phoneNumber ?? '').trim();
    if (phone.isNotEmpty) return phone;

    final email = (user.email ?? user.emailLower).trim();
    if (email.isNotEmpty) return email;

    return user.id;
  }

  String _emptyText({
    required AllUsersFilterMode mode,
    required String selectedTenant,
  }) {
    switch (mode) {
      case AllUsersFilterMode.all:
        return 'No users found';
      case AllUsersFilterMode.noTenant:
        return 'No users without tenant access found';
      case AllUsersFilterMode.tenant:
        return 'No users found for $selectedTenant';
    }
  }

  void _applyFilter({required AllUsersFilterMode mode, String? tenantId}) {
    final hqCtrl = ref.read(hqControllerProvider.notifier);
    final usersCtrl = ref.read(allUsersControllerProvider.notifier);

    switch (mode) {
      case AllUsersFilterMode.all:
        hqCtrl.setTargetTenant(null);
        usersCtrl.setUserFilter(mode: AllUsersFilterMode.all);
        SnackService.showInfo('Showing all users');
        return;

      case AllUsersFilterMode.noTenant:
        hqCtrl.setTargetTenant(null);
        usersCtrl.setUserFilter(mode: AllUsersFilterMode.noTenant);
        SnackService.showInfo('Showing users without tenant access');
        return;

      case AllUsersFilterMode.tenant:
        final cleanTenantId = tenantId?.trim();

        if (cleanTenantId == null || cleanTenantId.isEmpty) {
          hqCtrl.setTargetTenant(null);
          usersCtrl.setUserFilter(mode: AllUsersFilterMode.all);
          SnackService.showInfo('Showing all users');
          return;
        }

        hqCtrl.setTargetTenant(cleanTenantId);
        usersCtrl.setUserFilter(
          mode: AllUsersFilterMode.tenant,
          tenantId: cleanTenantId,
        );
        SnackService.showInfo('Target tenant: $cleanTenantId');
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allUsersControllerProvider);
    final usersCtrl = ref.read(allUsersControllerProvider.notifier);

    final selectedTenant = (ref.watch(hqTargetTenantIdProvider) ?? '').trim();
    final tenantsAsync = ref.watch(hqTenantsProvider);

    final filterMode = state.filterMode;

    final hasTenantFilter =
        filterMode == AllUsersFilterMode.tenant && selectedTenant.isNotEmpty;

    final isNoTenantFilter = filterMode == AllUsersFilterMode.noTenant;

    final mirrored = (state.targetTenantId ?? '').trim();

    if (filterMode == AllUsersFilterMode.tenant && selectedTenant != mirrored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;

        usersCtrl.setUserFilter(
          mode: selectedTenant.isEmpty
              ? AllUsersFilterMode.all
              : AllUsersFilterMode.tenant,
          tenantId: selectedTenant.isEmpty ? null : selectedTenant,
        );
      });
    }

    if (_searchCtl.text != state.search) {
      _searchCtl.value = _searchCtl.value.copyWith(text: state.search);
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                _UserFilterDropdown(
                  tenantsAsync: tenantsAsync,
                  filterMode: filterMode,
                  selectedTenant: selectedTenant,
                  onRetryTenants: () => ref.invalidate(hqTenantsProvider),
                  onChanged: _applyFilter,
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _searchCtl,
                        onChanged: usersCtrl.setSearch,
                        keyboardType: TextInputType.text,
                        decoration: InputDecoration(
                          hintText: 'Search by phone, email, or name…',
                          prefixIcon: const Icon(Icons.search),
                          suffixIcon: state.search.isEmpty
                              ? null
                              : IconButton(
                                  icon: const Icon(Icons.clear),
                                  onPressed: () {
                                    _searchCtl.clear();
                                    usersCtrl.setSearch('');
                                  },
                                ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      tooltip: 'Refresh tenants',
                      icon: const Icon(Icons.refresh),
                      onPressed: () => ref.invalidate(hqTenantsProvider),
                    ),
                  ],
                ),
              ],
            ),
          ),
          _UserFilterBanner(mode: filterMode, selectedTenant: selectedTenant),
          Expanded(
            child: RefreshIndicator(
              onRefresh: usersCtrl.refresh,
              child: Builder(
                builder: (_) {
                  if (state.loading && state.items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.error != null && state.items.isEmpty) {
                    return Center(child: Text('Error: ${state.error}'));
                  }

                  if (state.items.isEmpty) {
                    return Center(
                      child: Text(
                        _emptyText(
                          mode: filterMode,
                          selectedTenant: selectedTenant,
                        ),
                      ),
                    );
                  }

                  return ListView.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final user = state.items[i];

                      return UserRowTile(
                        user: user,
                        memberships: usersCtrl.membershipsForUser(user),
                        onTap: () async {
                          if (hasTenantFilter) {
                            await _openEditor(
                              targetTenantId: selectedTenant,
                              user: user,
                            );
                            return;
                          }

                          if (isNoTenantFilter) {
                            await _deleteUnassignedUserFlow(user);
                            return;
                          }

                          SnackService.showError(
                            'Pick a tenant first to edit access.',
                          );
                        },
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: !hasTenantFilter
            ? () => SnackService.showError(
                isNoTenantFilter
                    ? 'Switch to a tenant before creating users.'
                    : 'Pick a tenant first to create a tenant user.',
              )
            : () => _createUserFlow(selectedTenant),
        icon: const Icon(Icons.person_add),
        label: const Text('New user'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Local components
// ─────────────────────────────────────────────

class _UserFilterBanner extends StatelessWidget {
  const _UserFilterBanner({required this.mode, required this.selectedTenant});

  final AllUsersFilterMode mode;
  final String selectedTenant;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Row(
        children: [
          Icon(_icon, size: 18, color: Colors.grey.shade700),
          const SizedBox(width: 8),
          Expanded(
            child: Text(_text, style: TextStyle(color: Colors.grey.shade700)),
          ),
        ],
      ),
    );
  }

  IconData get _icon {
    switch (mode) {
      case AllUsersFilterMode.all:
        return Icons.people_alt_outlined;
      case AllUsersFilterMode.noTenant:
        return Icons.person_off_outlined;
      case AllUsersFilterMode.tenant:
        return Icons.filter_alt;
    }
  }

  String get _text {
    switch (mode) {
      case AllUsersFilterMode.all:
        return 'Showing all users. Pick a tenant to edit access or create tenant users.';
      case AllUsersFilterMode.noTenant:
        return 'Showing users with no tenant access. Tap a user to delete the global record.';
      case AllUsersFilterMode.tenant:
        return 'Filtering users by "$selectedTenant". You can edit access and create users for this tenant.';
    }
  }
}

class _UserFilterDropdown extends StatelessWidget {
  const _UserFilterDropdown({
    required this.tenantsAsync,
    required this.filterMode,
    required this.selectedTenant,
    required this.onChanged,
    required this.onRetryTenants,
  });

  static const String filterAll = '__all__';
  static const String filterNoTenant = '__no_tenant__';

  final AsyncValue<List<TenantProfile>> tenantsAsync;
  final AllUsersFilterMode filterMode;
  final String selectedTenant;

  final void Function({required AllUsersFilterMode mode, String? tenantId})
  onChanged;

  final VoidCallback onRetryTenants;

  String get _dropdownValue {
    switch (filterMode) {
      case AllUsersFilterMode.all:
        return filterAll;
      case AllUsersFilterMode.noTenant:
        return filterNoTenant;
      case AllUsersFilterMode.tenant:
        return selectedTenant.isEmpty ? filterAll : selectedTenant;
    }
  }

  @override
  Widget build(BuildContext context) {
    return tenantsAsync.when(
      loading: () => InputDecorator(
        decoration: const InputDecoration(
          labelText: 'User list filter / target tenant',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: Row(
          children: const [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            SizedBox(width: 10),
            Text('Loading tenants…'),
          ],
        ),
      ),
      error: (e, _) => InputDecorator(
        decoration: const InputDecoration(
          labelText: 'User list filter / target tenant',
          border: OutlineInputBorder(),
          isDense: true,
        ),
        child: Row(
          children: [
            const Icon(Icons.error_outline, size: 18),
            const SizedBox(width: 10),
            Expanded(child: Text('Failed to load tenants: $e')),
            const SizedBox(width: 10),
            TextButton(onPressed: onRetryTenants, child: const Text('Retry')),
          ],
        ),
      ),
      data: (tenants) {
        final options = List<TenantProfile>.from(tenants)
          ..sort((a, b) {
            final an = a.displayName.trim().toLowerCase();
            final bn = b.displayName.trim().toLowerCase();
            return an.compareTo(bn);
          });

        return DropdownButtonFormField<String>(
          initialValue: _dropdownValue,
          isExpanded: true,
          decoration: const InputDecoration(
            labelText: 'User list filter / target tenant',
            helperText:
                'Show all users, users without tenant access, or users for one tenant.',
            border: OutlineInputBorder(),
            isDense: true,
          ),
          items: [
            const DropdownMenuItem<String>(
              value: filterAll,
              child: Text('All users'),
            ),
            const DropdownMenuItem<String>(
              value: filterNoTenant,
              child: Text('No tenant users'),
            ),
            ...options.map((tenant) {
              final tenantId = tenant.id.trim().toLowerCase();
              final name = tenant.displayName.trim().isEmpty
                  ? tenantId
                  : tenant.displayName.trim();

              return DropdownMenuItem<String>(
                value: tenantId,
                child: Text('$name  ($tenantId)'),
              );
            }),
          ],
          onChanged: (value) {
            final next = (value ?? '').trim();

            if (next == filterAll) {
              onChanged(mode: AllUsersFilterMode.all);
              return;
            }

            if (next == filterNoTenant) {
              onChanged(mode: AllUsersFilterMode.noTenant);
              return;
            }

            onChanged(mode: AllUsersFilterMode.tenant, tenantId: next);
          },
        );
      },
    );
  }
}

// ─────────────────────────────────────────────
// Local dialog
// ─────────────────────────────────────────────

class _CreateTenantUserInput {
  const _CreateTenantUserInput({required this.phoneNumber, this.displayName});

  final String phoneNumber;
  final String? displayName;
}

Future<_CreateTenantUserInput?> showCreateTenantUserDialog(
  BuildContext context,
) async {
  final phoneCtl = TextEditingController();
  final nameCtl = TextEditingController();

  try {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Create user'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: phoneCtl,
                  decoration: const InputDecoration(
                    labelText: 'Phone number (E.164)',
                    hintText: '+2547…',
                    border: OutlineInputBorder(),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: nameCtl,
                  decoration: const InputDecoration(
                    labelText: 'Display name (optional)',
                    border: OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Create'),
              ),
            ],
          ),
        ) ??
        false;

    if (!ok) return null;

    final phone = phoneCtl.text.trim();
    final name = nameCtl.text.trim();

    if (phone.isEmpty) {
      SnackService.showError('Phone number is required');
      return null;
    }

    return _CreateTenantUserInput(
      phoneNumber: phone,
      displayName: name.isEmpty ? null : name,
    );
  } finally {
    phoneCtl.dispose();
    nameCtl.dispose();
  }
}
