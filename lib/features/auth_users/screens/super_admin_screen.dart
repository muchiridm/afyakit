// lib/users/screens/super_admin_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/auth_users/user_manager/controllers/user_manager_controller.dart';
import 'package:afyakit/features/auth_users/providers/super_admin_providers.dart';

class SuperAdminScreen extends ConsumerWidget {
  const SuperAdminScreen({super.key});

  Future<void> _promoteFlow(BuildContext context, WidgetRef ref) async {
    final input = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Promote to Superadmin'),
        content: TextField(
          controller: input,
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

    final uid = input.text.trim();
    if (ok == true && uid.isNotEmpty) {
      await ref
          .read(userManagerControllerProvider.notifier)
          .promoteSuperAdmin(uid);
      // no manual refresh: Firestore stream will reflect the change
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Promoted')));
    }
  }

  Future<void> _demote(BuildContext context, WidgetRef ref, String uid) async {
    await ref
        .read(userManagerControllerProvider.notifier)
        .demoteSuperAdmin(uid);
    // no manual refresh: Firestore stream will reflect the change
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Demoted')));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // use the sorted Firestore stream for display
    final adminsAsync = ref.watch(superAdminStreamSortedProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Super Admins (HQ)')),
      body: adminsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
        data: (users) {
          if (users.isEmpty) {
            return ListView(
              children: const [
                SizedBox(height: 200),
                Center(child: Text('No superadmins yet.')),
              ],
            );
          }
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              return ListTile(
                leading: const Icon(Icons.verified_user),
                title: Text(u.email ?? u.uid),
                subtitle: u.displayName == null ? null : Text(u.displayName!),
                trailing: TextButton(
                  onPressed: () => _demote(context, ref, u.uid),
                  child: const Text('Demote'),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _promoteFlow(context, ref),
        label: const Text('Promote UID'),
        icon: const Icon(Icons.upgrade),
      ),
    );
  }
}
