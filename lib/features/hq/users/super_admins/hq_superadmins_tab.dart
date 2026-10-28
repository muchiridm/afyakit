// lib/hq/users/super_admins/widgets/hq_superadmins_tab.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/hq/users/super_admins/super_admins_controller.dart';
import 'package:afyakit/features/hq/users/super_admins/super_admin_model.dart';

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
              final SuperAdmin u = users[i];

              // Phone-first label:
              final displayName = (u.displayName ?? '').trim();
              final hasDisplayName = displayName.isNotEmpty;

              final titleText = hasDisplayName
                  ? displayName
                  : (u.phoneNumber ?? u.uid);

              // Subtitle: phone + UID (email optional, last).
              final subtitleBits = <String>[];

              if (u.phoneNumber != null && u.phoneNumber!.trim().isNotEmpty) {
                subtitleBits.add(u.phoneNumber!.trim());
              }

              subtitleBits.add('UID: ${u.uid}');

              if (u.email != null && u.email!.trim().isNotEmpty) {
                subtitleBits.add(u.email!.trim());
              }

              final subtitle = subtitleBits.isEmpty
                  ? null
                  : Text(subtitleBits.join(' • '));

              final demoteLabel =
                  u.phoneNumber ?? u.displayName ?? u.email ?? u.uid;

              return ListTile(
                leading: const Icon(Icons.verified_user),
                title: Text(titleText),
                subtitle: subtitle,
                trailing: TextButton(
                  onPressed: () => ref
                      .read(superAdminsControllerProvider.notifier)
                      .demoteWithConfirm(
                        context,
                        uid: u.uid,
                        label: demoteLabel,
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
