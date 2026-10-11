import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/shell/hq_controller.dart';
import 'package:afyakit/features/hq/tenants/providers/hq_tenant_providers.dart';
import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/controllers/all_users_controller.dart';
import 'package:afyakit/features/hq/users/all_users/widgets/user_editor_screen.dart';
import 'package:afyakit/features/hq/users/all_users/widgets/user_row_tile.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HqAllUsersTab extends ConsumerStatefulWidget {
  const HqAllUsersTab({super.key});

  @override
  ConsumerState<HqAllUsersTab> createState() => _HqAllUsersTabState();
}

class _HqAllUsersTabState extends ConsumerState<HqAllUsersTab> {
  static const _allTenants = '__all__';
  static const _noTenant = '__no_tenant__';

  final _searchController = TextEditingController();
  final _selectedAppIds = <String>{};

  String? _appFilterTenantId;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(allUsersControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _selectTenant(String value) {
    final controller = ref.read(allUsersControllerProvider.notifier);
    final hqController = ref.read(hqControllerProvider.notifier);

    setState(() {
      _selectedAppIds.clear();
      _appFilterTenantId = value == _allTenants || value == _noTenant
          ? null
          : value;
    });

    if (value == _allTenants) {
      hqController.setTargetTenant(null);
      controller.setUserFilter(mode: AllUsersFilterMode.all);
    } else if (value == _noTenant) {
      hqController.setTargetTenant(null);
      controller.setUserFilter(mode: AllUsersFilterMode.noTenant);
    } else {
      hqController.setTargetTenant(value);
      controller.setUserFilter(
        mode: AllUsersFilterMode.tenant,
        tenantId: value,
      );
    }
  }

  void _toggleApp(String appId, bool selected) {
    setState(() {
      if (selected) {
        _selectedAppIds.add(appId);
      } else {
        _selectedAppIds.remove(appId);
      }
    });
  }

  List<AllUser> _filterUsers(
    List<AllUser> users,
    String tenantId,
    Set<String> selectedApps,
  ) {
    if (selectedApps.isEmpty || tenantId.isEmpty) {
      return users;
    }

    final controller = ref.read(allUsersControllerProvider.notifier);

    return users.where((user) {
      final memberships = controller.membershipsForUser(user);

      return memberships.any(
        (membership) =>
            membership.tenantId.trim().toLowerCase() == tenantId &&
            selectedApps.every(membership.hasAppMembership),
      );
    }).toList();
  }

  Future<void> _openEditor(
    String tenantId,
    AllUser user, {
    String? appId,
  }) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => UserEditorScreen(
          tenantId: tenantId,
          userUid: user.id,
          initialUser: user,
          initialAppId: appId,
        ),
      ),
    );

    if (changed == true && mounted) {
      await ref.read(allUsersControllerProvider.notifier).refresh();
    }
  }

  Future<void> _createUser(String tenantId) async {
    final phoneController = TextEditingController();
    final nameController = TextEditingController();

    try {
      final confirmed =
          await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: const Text('New tenant user'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(
                      labelText: 'Phone number',
                      hintText: '+2547…',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Display name (optional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Create'),
                ),
              ],
            ),
          ) ??
          false;

      if (!confirmed || !mounted) return;

      final phone = phoneController.text.trim();
      final name = nameController.text.trim();

      if (phone.isEmpty) {
        SnackService.showError('Phone number is required');
        return;
      }

      final controller = ref.read(allUsersControllerProvider.notifier);

      final uid = await controller.createTenantUser(
        tenantId: tenantId,
        phoneNumber: phone,
        displayName: name.isEmpty ? null : name,
      );

      if (uid == null || uid.trim().isEmpty || !mounted) return;

      await controller.refresh();

      if (!mounted) return;

      final users = ref.read(allUsersControllerProvider).items;
      AllUser? createdUser;

      for (final user in users) {
        if (user.id == uid.trim()) {
          createdUser = user;
          break;
        }
      }

      final changed = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => UserEditorScreen(
            tenantId: tenantId,
            userUid: uid.trim(),
            initialUser: createdUser,
          ),
        ),
      );

      if (changed == true && mounted) {
        await controller.refresh();
      }
    } finally {
      phoneController.dispose();
      nameController.dispose();
    }
  }

  Future<void> _deleteUnassignedUser(AllUser user) async {
    final label = user.displayName?.trim().isNotEmpty == true
        ? user.displayName!
        : user.phoneNumber ?? user.id;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete global user?'),
            content: Text(
              'Permanently delete "$label"?\n\n'
              'This action is allowed only when the user has no '
              'tenant account or membership.\n\n'
              'UID: ${user.id}',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed || !mounted) return;

    final controller = ref.read(allUsersControllerProvider.notifier);
    final deleted = await controller.deleteGlobalUser(user.id);

    if (deleted && mounted) {
      await controller.refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allUsersControllerProvider);
    final controller = ref.read(allUsersControllerProvider.notifier);

    final selectedTenant = (ref.watch(hqTargetTenantIdProvider) ?? '')
        .trim()
        .toLowerCase();

    final isTenantMode =
        state.filterMode == AllUsersFilterMode.tenant &&
        selectedTenant.isNotEmpty;

    final isNoTenantMode = state.filterMode == AllUsersFilterMode.noTenant;

    final filterValue = isTenantMode
        ? selectedTenant
        : isNoTenantMode
        ? _noTenant
        : _allTenants;

    // Prevent app selections from a previous tenant being applied
    // if another HQ screen changes the target tenant.
    final effectiveSelectedApps =
        _appFilterTenantId == selectedTenant && isTenantMode
        ? _selectedAppIds
        : <String>{};

    if (_appFilterTenantId != (isTenantMode ? selectedTenant : null)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(() {
          _selectedAppIds.clear();
          _appFilterTenantId = isTenantMode ? selectedTenant : null;
        });
      });
    }

    if (isTenantMode && state.targetTenantId != selectedTenant) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ref
            .read(allUsersControllerProvider.notifier)
            .setUserFilter(
              mode: AllUsersFilterMode.tenant,
              tenantId: selectedTenant,
            );
      });
    }

    final tenantsAsync = ref.watch(hqTenantsProvider);
    final appsAsync = isTenantMode
        ? ref.watch(hqAppProfilesProvider(selectedTenant))
        : null;

    final visibleUsers = _filterUsers(
      state.items,
      selectedTenant,
      effectiveSelectedApps,
    );

    if (_searchController.text != state.search) {
      _searchController.value = _searchController.value.copyWith(
        text: state.search,
        selection: TextSelection.collapsed(offset: state.search.length),
      );
    }

    final theme = Theme.of(context);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Filter users', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),

                tenantsAsync.when(
                  loading: () => const LinearProgressIndicator(),
                  error: (error, _) => Row(
                    children: [
                      const Expanded(child: Text('Unable to load tenants')),
                      TextButton(
                        onPressed: () => ref.invalidate(hqTenantsProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                  data: (tenants) {
                    final sorted = List<TenantProfile>.from(tenants)
                      ..sort((a, b) => a.id.compareTo(b.id));

                    final values = sorted
                        .map((tenant) => tenant.id.trim().toLowerCase())
                        .toSet();

                    return DropdownButtonFormField<String>(
                      key: ValueKey(filterValue),
                      initialValue:
                          values.contains(filterValue) ||
                              filterValue == _allTenants ||
                              filterValue == _noTenant
                          ? filterValue
                          : null,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Tenant',
                        prefixIcon: Icon(Icons.apartment_outlined),
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: _allTenants,
                          child: Text('All tenants'),
                        ),
                        const DropdownMenuItem(
                          value: _noTenant,
                          child: Text('No tenant'),
                        ),
                        ...sorted.map(
                          (tenant) => DropdownMenuItem(
                            value: tenant.id.trim().toLowerCase(),
                            child: Text(
                              tenant.id,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) _selectTenant(value);
                      },
                    );
                  },
                ),

                if (isTenantMode && appsAsync != null) ...[
                  const SizedBox(height: 14),
                  _ApplicationCheckboxes(
                    appsAsync: appsAsync,
                    selectedIds: effectiveSelectedApps,
                    onToggle: _toggleApp,
                    onClear: () => setState(_selectedAppIds.clear),
                    onRetry: () =>
                        ref.invalidate(hqAppProfilesProvider(selectedTenant)),
                  ),
                ],

                const SizedBox(height: 14),
                TextField(
                  controller: _searchController,
                  onChanged: controller.setSearch,
                  decoration: InputDecoration(
                    hintText: 'Search name, phone or email',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: state.search.isEmpty
                        ? null
                        : IconButton(
                            tooltip: 'Clear search',
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              _searchController.clear();
                              controller.setSearch('');
                            },
                          ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${visibleUsers.length} of '
                        '${state.items.length} loaded users',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Refresh users',
                      onPressed: state.loading
                          ? null
                          : () => controller.refresh(),
                      icon: const Icon(Icons.refresh),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: RefreshIndicator(
              onRefresh: controller.refresh,
              child: Builder(
                builder: (context) {
                  if (state.loading && state.items.isEmpty) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  if (state.error != null && state.items.isEmpty) {
                    return Center(child: Text('Error: ${state.error}'));
                  }

                  if (visibleUsers.isEmpty) {
                    return ListView(
                      children: [
                        const SizedBox(height: 100),
                        Center(
                          child: Text(
                            effectiveSelectedApps.isNotEmpty
                                ? 'No matching users in loaded results.'
                                : 'No users found.',
                          ),
                        ),
                      ],
                    );
                  }

                  return ListView.separated(
                    itemCount: visibleUsers.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final user = visibleUsers[index];

                      return UserRowTile(
                        user: user,
                        memberships: controller.membershipsForUser(user),
                        onTap: () async {
                          if (isTenantMode) {
                            await _openEditor(
                              selectedTenant,
                              user,
                              appId: effectiveSelectedApps.length == 1
                                  ? effectiveSelectedApps.single
                                  : null,
                            );
                          } else if (isNoTenantMode) {
                            await _deleteUnassignedUser(user);
                          } else {
                            SnackService.showInfo(
                              'Select a tenant to edit user access.',
                            );
                          }
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
        onPressed: isTenantMode ? () => _createUser(selectedTenant) : null,
        icon: const Icon(Icons.person_add_alt_1),
        label: const Text('New user'),
      ),
    );
  }
}

class _ApplicationCheckboxes extends StatelessWidget {
  const _ApplicationCheckboxes({
    required this.appsAsync,
    required this.selectedIds,
    required this.onToggle,
    required this.onClear,
    required this.onRetry,
  });

  final AsyncValue<List<AppProfile>> appsAsync;
  final Set<String> selectedIds;
  final void Function(String, bool) onToggle;
  final VoidCallback onClear;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return appsAsync.when(
      loading: () => const LinearProgressIndicator(),
      error: (error, _) => Row(
        children: [
          const Expanded(child: Text('Unable to load applications')),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
      data: (apps) {
        if (apps.isEmpty) {
          return const Text('No registered applications.');
        }

        final sorted = List<AppProfile>.from(apps)
          ..sort(
            (a, b) => a.displayName.toLowerCase().compareTo(
              b.displayName.toLowerCase(),
            ),
          );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('Applications', style: theme.textTheme.titleSmall),
                const Spacer(),
                if (selectedIds.isNotEmpty)
                  TextButton(onPressed: onClear, child: const Text('Clear')),
              ],
            ),
            Wrap(
              spacing: 16,
              runSpacing: 4,
              children: sorted.map((app) {
                final appId = app.id.trim().toLowerCase();

                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onToggle(appId, !selectedIds.contains(appId)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Checkbox(
                        value: selectedIds.contains(appId),
                        onChanged: (checked) =>
                            onToggle(appId, checked ?? false),
                        visualDensity: VisualDensity.compact,
                      ),
                      Text(
                        app.active
                            ? app.displayName
                            : '${app.displayName} (inactive)',
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
            Text(
              selectedIds.isEmpty
                  ? 'All tenant users'
                  : 'Users in any selected application',
              style: theme.textTheme.bodySmall,
            ),
          ],
        );
      },
    );
  }
}
