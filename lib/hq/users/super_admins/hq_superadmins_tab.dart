import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/users/super_admins/super_admins_controller.dart';

class HqSuperadminsTab extends ConsumerStatefulWidget {
  const HqSuperadminsTab({super.key});
  @override
  ConsumerState<HqSuperadminsTab> createState() => _HqSuperadminsTabState();
}

class _HqSuperadminsTabState extends ConsumerState<HqSuperadminsTab> {
  @override
  void initState() {
    super.initState();
    // Kick off a REST-backed load once the widget is mounted
    Future.microtask(
      () => ref.read(superAdminsControllerProvider.notifier).load(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(superAdminsControllerProvider);

    if (state.isLoading && state.items.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if ((state.error ?? '').isNotEmpty && state.items.isEmpty) {
      return Center(child: Text('Error: ${state.error}'));
    }
    final users = state.items;
    if (users.isEmpty) {
      return const Center(child: Text('No superadmins yet.'));
    }

    return Stack(
      children: [
        RefreshIndicator(
          onRefresh: () =>
              ref.read(superAdminsControllerProvider.notifier).load(),
          child: ListView.separated(
            itemCount: users.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final u = users[i];
              final title = u.email ?? u.uid;
              final subtitle =
                  (u.displayName == null || u.displayName!.trim().isEmpty)
                  ? null
                  : Text(u.displayName!);

              return ListTile(
                leading: const Icon(Icons.verified_user),
                title: Text(title),
                subtitle: subtitle,
                trailing: TextButton(
                  onPressed: () => ref
                      .read(superAdminsControllerProvider.notifier)
                      .demoteWithConfirm(
                        context,
                        uid: u.uid,
                        label: u.email ?? u.displayName ?? u.uid,
                      ),
                  child: const Text('Demote'),
                ),
              );
            },
          ),
        ),
        Positioned(
          right: 16,
          bottom: 16,
          child: FloatingActionButton.extended(
            onPressed: () => ref
                .read(superAdminsControllerProvider.notifier)
                .promoteViaPrompt(context),
            label: const Text('Promote UID'),
            icon: const Icon(Icons.upgrade),
          ),
        ),
      ],
    );
  }
}
