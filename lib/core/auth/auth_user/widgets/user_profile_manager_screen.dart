// lib/core/auth/auth_user/widgets/user_profile_manager_screen.dart
// Presentation only: tenant/app account access. No Native Contact editing.

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/auth/auth_user/utils/resolve_user_display.dart';
import 'package:afyakit/core/auth/auth_user/utils/user_format.dart';
import 'package:afyakit/core/auth/auth_user/widgets/user_profile_card.dart';
import 'package:afyakit/core/auth/auth_user/widgets/user_profile_editor_screen.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/features/hq/users/tenant_users_provider.dart';
import 'package:afyakit/shared/layout/app_header.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

class UserProfileManagerScreen extends ConsumerWidget {
  const UserProfileManagerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentUser = ref.watch(currentUserProvider);

    return currentUser.when(
      loading: () => _page(const Center(child: CircularProgressIndicator())),
      error: (_, __) =>
          _page(const Center(child: Text('Could not load your account.'))),
      data: (actor) {
        if (actor == null || !actor.canManageUsers) {
          return _page(
            const Center(child: Text('You do not have access to this page.')),
          );
        }

        final appId = actor.activeAppId;
        if (appId == null || appId.isEmpty) {
          return _page(const Center(child: Text('No application selected.')));
        }

        final users = ref.watch(tenantUsersProvider);
        return _page(
          users.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) =>
                const Center(child: Text('Could not load user accounts.')),
            data: (allUsers) {
              // Only show accounts belonging to the actor's tenant and app.
              // This screen does not grant membership to other applications.
              final visible = allUsers
                  .where(
                    (user) =>
                        user.tenantId == actor.tenantId &&
                        user.hasAppMembership(appId),
                  )
                  .map((user) => user.forApp(appId))
                  .toList();

              visible.sort((a, b) {
                if (a.uid == actor.uid && b.uid != actor.uid) return -1;
                if (b.uid == actor.uid && a.uid != actor.uid) return 1;
                final order = a.displayLabel().toLowerCase().compareTo(
                  b.displayLabel().toLowerCase(),
                );
                return order != 0 ? order : a.uid.compareTo(b.uid);
              });

              if (visible.isEmpty) {
                return const Center(
                  child: Text('No user accounts found for this application.'),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Accounts (${visible.length})',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  for (final user in visible)
                    UserProfileCard(
                      key: ValueKey(user.uid),
                      user: user,
                      roleLabelOverride: staffRoleLabel(user),
                      onTap: actor.canManageUser(user)
                          ? () => _openEditor(context, user)
                          : null,
                    ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _page(Widget body) => AppPage(
    maxWidth: 900,
    scrollable: true,
    header: const AppHeader(title: 'Manage User Access'),
    body: Padding(padding: const EdgeInsets.all(16), child: body),
  );

  void _openEditor(BuildContext context, AuthUser target) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => UserProfileEditorScreen(user: target),
      ),
    );
  }
}
