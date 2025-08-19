// lib/hq/global_users/global_users_screen.dart
import 'package:afyakit/users/user_manager/providers/global_user_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/users/user_manager/models/global_user_model.dart';

class GlobalUsersScreen extends ConsumerStatefulWidget {
  const GlobalUsersScreen({super.key});

  @override
  ConsumerState<GlobalUsersScreen> createState() => _GlobalUsersScreenState();
}

class _GlobalUsersScreenState extends ConsumerState<GlobalUsersScreen> {
  final _searchCtl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _searchCtl.text = ref.read(globalUsersSearchProvider);
  }

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(globalUsersStreamProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Global Users'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(56),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchCtl,
              onChanged: (v) =>
                  ref.read(globalUsersSearchProvider.notifier).state = v,
              decoration: InputDecoration(
                hintText: 'Search by email…',
                prefixIcon: const Icon(Icons.search),
                contentPadding: const EdgeInsets.symmetric(
                  vertical: 0,
                  horizontal: 12,
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ),
      ),
      body: usersAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return const Center(child: Text('No users found'));
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (_, i) => _UserRowTile(user: users[i]),
          );
        },
      ),
    );
  }
}

class _UserRowTile extends ConsumerWidget {
  const _UserRowTile({required this.user});
  final GlobalUser user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = user.email ?? user.emailLower;
    final name = (user.displayName ?? '').trim();

    // Live memberships stream (Firestore) for this user
    final memsAsync = ref.watch(userMembershipsStreamProvider(user.id));

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: CircleAvatar(
          radius: 20,
          foregroundImage: (user.photoURL != null && user.photoURL!.isNotEmpty)
              ? NetworkImage(user.photoURL!)
              : null,
          child: (user.photoURL == null || user.photoURL!.isEmpty)
              ? Text(_initial(email))
              : null,
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                email,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            if (user.disabled)
              const Padding(
                padding: EdgeInsets.only(left: 8),
                child: Icon(Icons.block, size: 16, color: Colors.redAccent),
              ),
            const SizedBox(width: 8),
            _countBadge(user.tenantCount),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // name • last login
            Padding(
              padding: const EdgeInsets.only(top: 2, bottom: 6),
              child: Text(
                [
                  if (name.isNotEmpty) name,
                  if (user.lastLoginAt != null)
                    'last login: ${_fmtDateShort(user.lastLoginAt)}',
                ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            // tenant chips (live from Firestore)
            memsAsync.when(
              loading: () => const LinearProgressIndicator(minHeight: 2),
              error: (e, _) => Text('memberships: $e'),
              data: (mems) {
                if (mems.isEmpty && user.tenantIds.isEmpty) {
                  return Chip(
                    label: const Text('no tenants'),
                    backgroundColor: Colors.grey.shade200,
                    visualDensity: VisualDensity.compact,
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  );
                }

                final keys = user.tenantIds.isNotEmpty
                    ? user.tenantIds
                    : (mems.keys.toList()..sort());

                return Wrap(
                  spacing: 6,
                  runSpacing: -6,
                  children: keys.map((tid) {
                    final m = mems[tid];
                    final role = (m?['role'] as String?) ?? '—';
                    final active = m?['active'] == true;
                    return _tenantChip(tid, role, active);
                  }).toList(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _tenantChip(String tenantId, String role, bool active) {
    return Chip(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      visualDensity: VisualDensity.compact,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$tenantId: $role'),
          const SizedBox(width: 6),
          Icon(
            active ? Icons.check_circle : Icons.cancel,
            size: 14,
            color: active ? Colors.green : Colors.orange,
          ),
        ],
      ),
    );
  }

  Widget _countBadge(int count) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.blue.withOpacity(0.08),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.layers, size: 14),
          const SizedBox(width: 4),
          Text('$count'),
        ],
      ),
    );
  }

  String _initial(String s) {
    final t = s.trim();
    return t.isEmpty ? '?' : t[0].toUpperCase();
  }

  String _fmtDateShort(DateTime? d) {
    if (d == null) return '';
    final now = DateTime.now();
    final sameDay =
        d.year == now.year && d.month == now.month && d.day == now.day;
    if (sameDay) {
      final hh = d.hour.toString().padLeft(2, '0');
      final mm = d.minute.toString().padLeft(2, '0');
      return '$hh:$mm';
    }
    final y = d.year.toString().padLeft(4, '0');
    final m = d.month.toString().padLeft(2, '0');
    final day = d.day.toString().padLeft(2, '0');
    return '$y-$m-$day';
  }
}
