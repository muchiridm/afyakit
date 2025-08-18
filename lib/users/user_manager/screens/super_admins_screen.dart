// lib/hq/super_admins/super_admins_screen.dart
import 'package:flutter/material.dart';
import 'package:afyakit/users/user_manager/services/hq_api_client.dart';
import 'package:afyakit/users/user_manager/models/super_admim_model.dart';

class SuperAdminsScreen extends StatefulWidget {
  final HqApiClient api;
  const SuperAdminsScreen({super.key, required this.api});

  @override
  State<SuperAdminsScreen> createState() => _SuperAdminsScreenState();
}

class _SuperAdminsScreenState extends State<SuperAdminsScreen> {
  late Future<List<SuperAdmin>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.api.listSuperAdmins();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = widget.api.listSuperAdmins();
    });
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
            return const Center(child: Text('No superadmins yet.'));
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
                    onPressed: () async {
                      await widget.api.setSuperAdmin(uid: u.uid, value: false);
                      await _refresh();
                    },
                    child: const Text('Demote'),
                  ),
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
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
          if (ok == true && controller.text.trim().isNotEmpty) {
            await widget.api.setSuperAdmin(
              uid: controller.text.trim(),
              value: true,
            );
            await _refresh();
          }
        },
        label: const Text('Promote UID'),
        icon: const Icon(Icons.upgrade),
      ),
    );
  }
}
