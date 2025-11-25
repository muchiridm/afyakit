import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/users/all_users/all_users_controller.dart';
import 'package:afyakit/hq/users/all_users/widgets/user_row_tile.dart';

class HqAllUsersTab extends ConsumerStatefulWidget {
  const HqAllUsersTab({super.key});

  @override
  ConsumerState<HqAllUsersTab> createState() => _HqAllUsersTabState();
}

class _HqAllUsersTabState extends ConsumerState<HqAllUsersTab> {
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    // initial load via controller
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(allUsersControllerProvider.notifier).load();
    });
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _openInviteSheet(AllUsersController ctrl) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: _InviteUserSheet(
          onSubmit: (email, role) async {
            await ctrl.inviteUser(email: email, role: role);
            if (mounted) {
              Navigator.of(context).pop();
              await ctrl.refresh();
            }
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allUsersControllerProvider);
    final ctrl = ref.read(allUsersControllerProvider.notifier);

    // reflect controller state into the field (no loop—value copy only)
    if (_searchCtl.text != state.search) {
      _searchCtl.value = _searchCtl.value.copyWith(text: state.search);
    }

    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: TextField(
              controller: _searchCtl,
              onChanged: ctrl.setSearch, // controller owns debounce + load
              decoration: InputDecoration(
                hintText: 'Search by email…',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: state.search.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchCtl.clear();
                          ctrl.setSearch('');
                        },
                      ),
                contentPadding: const EdgeInsets.symmetric(horizontal: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: ctrl.refresh,
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
                        fetchMemberships: () => ctrl.fetchMemberships(u.id),
                        onUpdateMembership: (tenantId, role, active) =>
                            ctrl.updateMembership(
                              u.id,
                              tenantId,
                              role: role,
                              active: active,
                            ),
                        onRemoveMembership: (tenantId) =>
                            ctrl.removeMembership(u.id, tenantId),
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
        icon: const Icon(Icons.person_add),
        label: const Text('Invite User'),
        onPressed: () => _openInviteSheet(ctrl),
      ),
    );
  }
}

class _InviteUserSheet extends StatefulWidget {
  const _InviteUserSheet({required this.onSubmit});

  final Future<void> Function(String email, String role) onSubmit;

  @override
  State<_InviteUserSheet> createState() => _InviteUserSheetState();
}

class _InviteUserSheetState extends State<_InviteUserSheet> {
  final _emailCtl = TextEditingController();
  String _role = 'client';
  bool _submitting = false;

  @override
  void dispose() {
    _emailCtl.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    final email = _emailCtl.text.trim();
    if (email.isEmpty) return;

    setState(() => _submitting = true);
    try {
      await widget.onSubmit(email, _role);
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
      ).copyWith(top: 16, bottom: 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Invite User', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          TextField(
            controller: _emailCtl,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email',
              hintText: 'user@example.com',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _role,
            decoration: const InputDecoration(
              labelText: 'Role',
              border: OutlineInputBorder(),
            ),
            items: const [
              DropdownMenuItem(value: 'owner', child: Text('Owner')),
              DropdownMenuItem(value: 'admin', child: Text('Admin')),
              DropdownMenuItem(value: 'manager', child: Text('Manager')),
              DropdownMenuItem(value: 'staff', child: Text('Staff')),
              DropdownMenuItem(value: 'client', child: Text('Client')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() => _role = value);
            },
          ),
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton.icon(
              icon: _submitting
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(_submitting ? 'Inviting…' : 'Send Invite'),
              onPressed: _submitting ? null : _handleSubmit,
            ),
          ),
        ],
      ),
    );
  }
}
