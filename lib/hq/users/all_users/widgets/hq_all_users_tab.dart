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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(allUsersControllerProvider);
    final ctrl = ref.read(allUsersControllerProvider.notifier);

    // reflect controller state into the field (no loop—value copy only)
    if (_searchCtl.text != state.search) {
      _searchCtl.value = _searchCtl.value.copyWith(text: state.search);
    }

    return Column(
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
                      fetchMemberships: () =>
                          ctrl.fetchMemberships(u.id), // controller call
                    );
                  },
                );
              },
            ),
          ),
        ),
      ],
    );
  }
}
