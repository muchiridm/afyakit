// lib/hq/users/all_users/hq_all_users_tab.dart

import 'package:afyakit/features/hq/users/all_users/all_user_model.dart';
import 'package:afyakit/features/hq/users/all_users/all_users_controller.dart';
import 'package:afyakit/features/hq/users/all_users/widgets/user_editor_screen.dart';
import 'package:afyakit/features/hq/users/all_users/widgets/user_row_tile.dart';
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

  void _openEditor({AllUser? user}) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserEditorScreen(initialUser: user),
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
              keyboardType: TextInputType.text,
              decoration: InputDecoration(
                hintText: 'Search by phone or email…',
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
                        onTap: () => _openEditor(user: u),
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
        onPressed: () => _openEditor(user: null),
        icon: const Icon(Icons.person_add),
        label: const Text('New user'),
      ),
    );
  }
}
