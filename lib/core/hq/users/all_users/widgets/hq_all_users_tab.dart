// lib/hq/users/all_users/hq_all_users_tab.dart

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
      final ctrl = ref.read(allUsersControllerProvider.notifier);
      await ctrl.refresh();
      // ignore: discarded_futures
      ctrl.fetchMemberships(user.id);
    }
  }

  Future<void> _createUserFlow(String targetTenantId) async {
    final phoneCtl = TextEditingController();
    final nameCtl = TextEditingController();

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

    final phone = phoneCtl.text.trim();
    final name = nameCtl.text.trim();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      phoneCtl.dispose();
      nameCtl.dispose();
    });

    if (!ok) return;

    if (phone.isEmpty) {
      SnackService.showError('Phone number is required');
      return;
    }

    final ctrl = ref.read(allUsersControllerProvider.notifier);

    final uid = await ctrl.hqCreateTenantUser(
      targetTenantId: targetTenantId,
      phoneNumber: phone,
      displayName: name.isEmpty ? null : name,
    );

    if (uid == null || uid.trim().isEmpty) return;
    final createdUid = uid.trim();

    // ignore: discarded_futures
    ctrl.fetchMemberships(createdUid);

    await ctrl.refresh();

    final latest = ref.read(allUsersControllerProvider);
    final AllUser? maybeUser =
        latest.items.where((u) => u.id == createdUid).isEmpty
        ? null
        : latest.items.firstWhere((u) => u.id == createdUid);

    if (!mounted) return;

    final changed = await _openEditorUid(
      targetTenantId: targetTenantId,
      uid: createdUid,
      initialUser: maybeUser,
    );

    if (changed == true && mounted) {
      await ctrl.refresh();
      // ignore: discarded_futures
      ctrl.fetchMemberships(createdUid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allUsersControllerProvider);
    final usersCtrl = ref.read(allUsersControllerProvider.notifier);

    // ✅ Persisted HQ selection (survives tab switching)
    final hqCtrl = ref.read(hqControllerProvider.notifier);
    final selectedTenant = (ref.watch(hqTargetTenantIdProvider) ?? '').trim();

    // ✅ Mirror HQ selection into AllUsersController (one-way sync)
    // Do it post-frame to avoid setState/notify during build.
    final mirrored = (state.targetTenantId ?? '').trim();
    if (selectedTenant != mirrored) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        usersCtrl.setTargetTenant(
          selectedTenant.isEmpty ? null : selectedTenant,
        );
      });
    }

    // Keep search controller synced with provider state
    if (_searchCtl.text != state.search) {
      _searchCtl.value = _searchCtl.value.copyWith(text: state.search);
    }

    final tenantsAsync = ref.watch(hqTenantsProvider);

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                tenantsAsync.when(
                  loading: () => InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Target tenant',
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
                      labelText: 'Target tenant',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, size: 18),
                        const SizedBox(width: 10),
                        Expanded(child: Text('Failed to load tenants: $e')),
                        const SizedBox(width: 10),
                        TextButton(
                          onPressed: () => ref.invalidate(hqTenantsProvider),
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                  data: (List<TenantProfile> tenants) {
                    final options = List<TenantProfile>.from(tenants)
                      ..sort((a, b) {
                        final an = a.displayName.trim().toLowerCase();
                        final bn = b.displayName.trim().toLowerCase();
                        return an.compareTo(bn);
                      });

                    return DropdownButtonFormField<String>(
                      initialValue: selectedTenant.isEmpty
                          ? null
                          : selectedTenant,
                      isExpanded: true,
                      decoration: const InputDecoration(
                        labelText: 'Target tenant',
                        helperText:
                            'Used for editing tenant access and creating tenant users.',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      items: [
                        const DropdownMenuItem<String>(
                          value: null,
                          child: Text('— Select tenant —'),
                        ),
                        ...options.map((t) {
                          final slug = t.id.trim().toLowerCase();
                          final name = t.displayName.trim().isEmpty
                              ? slug
                              : t.displayName.trim();
                          return DropdownMenuItem<String>(
                            value: slug,
                            child: Text('$name  ($slug)'),
                          );
                        }),
                      ],
                      onChanged: (v) {
                        final next = (v ?? '').trim();
                        hqCtrl.setTargetTenant(next.isEmpty ? null : next);
                        // AllUsersController mirrors via build post-frame sync
                        if (next.isNotEmpty) {
                          SnackService.showInfo('Target tenant: $next');
                        }
                      },
                    );
                  },
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
                          hintText: 'Search by phone…',
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
          if (selectedTenant.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: Colors.grey.shade700,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Pick a target tenant above to edit access.',
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                  ),
                ],
              ),
            ),
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
                    return const Center(child: Text('No users found'));
                  }

                  return ListView.separated(
                    itemCount: state.items.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final u = state.items[i];

                      return UserRowTile(
                        user: u,
                        membershipsMap: state.membershipsByUid[u.id],
                        onTap: () async {
                          if (selectedTenant.isEmpty) {
                            SnackService.showError(
                              'Pick a target tenant first.',
                            );
                            return;
                          }
                          await _openEditor(
                            targetTenantId: selectedTenant,
                            user: u,
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
        onPressed: selectedTenant.isEmpty
            ? () => SnackService.showError('Pick a target tenant first.')
            : () => _createUserFlow(selectedTenant),
        icon: const Icon(Icons.person_add),
        label: const Text('New user'),
      ),
    );
  }
}
