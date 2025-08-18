// lib/hq/super_admins/super_admins_screen.dart
import 'package:afyakit/users/user_manager/controllers/user_manager_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/users/user_manager/models/super_admim_model.dart';

class SuperAdminsScreen extends ConsumerStatefulWidget {
  const SuperAdminsScreen({super.key});

  @override
  ConsumerState<SuperAdminsScreen> createState() => _SuperAdminsScreenState();
}

class _SuperAdminsScreenState extends ConsumerState<SuperAdminsScreen> {
  late Future<List<SuperAdmin>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  Future<List<SuperAdmin>> _load() async {
    final ctrl = ref.read(userManagerControllerProvider.notifier);
    return ctrl.listSuperAdmins();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _load();
    });
  }

  Future<void> _demote(String uid) async {
    final ctrl = ref.read(userManagerControllerProvider.notifier);
    await ctrl.demoteSuperAdmin(uid);
    await _refresh();
  }

  Future<void> _promoteFlow() async {
    final controller = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote to Superadmin'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: 'User UID'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Promote'),
          ),
        ],
      ),
    );

    final uid = controller.text.trim();
    if (ok == true && uid.isNotEmpty) {
      final ctrl = ref.read(userManagerControllerProvider.notifier);
      await ctrl.promoteSuperAdmin(uid);
      await _refresh();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Super Admins (HQ)')),
      body: FutureBuilder<List<SuperAdmin>>(
        future: _future,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(child: Text('Error: ${snap.error}'));
          }
          final users = snap.data ?? const <SuperAdmin>[];
          if (users.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                children: const [
                  SizedBox(height: 200),
                  Center(child: Text('No superadmins yet. Pull to refresh.')),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.separated(
              itemCount: users.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final u = users[i];
                return ListTile(
                  leading: const Icon(Icons.verified_user),
                  title: Text(u.email ?? u.uid),
                  subtitle: u.displayName == null ? null : Text(u.displayName!),
                  trailing: TextButton(
                    onPressed: () => _demote(u.uid),
                    child: const Text('Demote'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _promoteFlow,
        label: const Text('Promote UID'),
        icon: const Icon(Icons.upgrade),
      ),
    );
  }
}
