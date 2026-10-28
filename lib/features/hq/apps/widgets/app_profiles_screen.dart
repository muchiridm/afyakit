// lib/features/hq/apps/widgets/app_profiles_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';

import 'package:afyakit/features/hq/apps/controllers/app_profile_controller.dart';
import 'package:afyakit/features/hq/apps/providers/hq_app_profiles_provider.dart';
import 'package:afyakit/features/hq/apps/widgets/app_branding_screen.dart';
import 'package:afyakit/features/hq/apps/widgets/app_profile_editor.dart';

class AppProfilesScreen extends ConsumerWidget {
  const AppProfilesScreen({super.key, required this.tenant});

  final TenantProfile tenant;

  Future<void> _refresh(WidgetRef ref) {
    return ref.refresh(hqAppProfilesProvider(tenant.id).future);
  }

  Future<void> _openBranding(
    BuildContext context,
    WidgetRef ref,
    AppProfile app,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => AppBrandingScreen(tenantId: tenant.id, initial: app),
      ),
    );

    if (!context.mounted) return;

    // Reload app metadata after branding changes.
    ref.invalidate(hqAppProfilesProvider(tenant.id));
  }

  Future<void> _openEditor(
    BuildContext context,
    WidgetRef ref,
    AppProfile? app,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (sheetContext) {
        return ProviderScope(
          parent: ProviderScope.containerOf(sheetContext),
          overrides: [
            appProfileEditorInputProvider.overrideWithValue(
              AppProfileEditorInput(tenant: tenant, initial: app),
            ),
          ],
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            ),
            child: const AppProfileEditor(),
          ),
        );
      },
    );

    if (!context.mounted) return;

    // Reload after app creation, editing or deletion.
    ref.invalidate(hqAppProfilesProvider(tenant.id));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncApps = ref.watch(hqAppProfilesProvider(tenant.id));

    return Scaffold(
      appBar: AppBar(
        title: Text('Apps · ${tenant.id}'),
        actions: [
          IconButton(
            tooltip: 'Refresh apps',
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.invalidate(hqAppProfilesProvider(tenant.id));
            },
          ),
        ],
      ),

      body: asyncApps.when(
        loading: () => const Center(child: CircularProgressIndicator()),

        error: (error, _) => _ErrorState(
          message: 'Failed to load apps: $error',
          onRetry: () {
            ref.invalidate(hqAppProfilesProvider(tenant.id));
          },
        ),

        data: (apps) {
          if (apps.isEmpty) {
            return RefreshIndicator(
              onRefresh: () => _refresh(ref),
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 140),
                  Center(child: Text('No app profiles yet.')),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => _refresh(ref),
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(12),
              itemCount: apps.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),

              itemBuilder: (context, index) {
                final app = apps[index];

                return _AppTile(
                  profile: app,
                  onBranding: () => _openBranding(context, ref, app),
                  onEdit: () => _openEditor(context, ref, app),
                );
              },
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(context, ref, null),
        icon: const Icon(Icons.add),
        label: const Text('Create app'),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// App overview tile
// ─────────────────────────────────────────────

class _AppTile extends StatelessWidget {
  const _AppTile({
    required this.profile,
    required this.onBranding,
    required this.onEdit,
  });

  final AppProfile profile;
  final VoidCallback onBranding;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final enabledCount = profile.features.values.values
        .where((enabled) => enabled)
        .length;

    final name = profile.displayName.trim().isNotEmpty
        ? profile.displayName.trim()
        : profile.id;

    final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';

    final primary = profile.primaryColor;

    final details = profile.details;

    final whatsapp = details.whatsapp?.trim() ?? '';

    final mobileMoneyName = details.mobileMoneyName?.trim() ?? '';

    final mobileMoneyNumber = details.mobileMoneyNumber?.trim() ?? '';

    final registrationNumber = details.registrationNumber?.trim() ?? '';

    final hasBusinessDetails =
        whatsapp.isNotEmpty ||
        mobileMoneyNumber.isNotEmpty ||
        registrationNumber.isNotEmpty;

    final identity = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 24,
          backgroundColor: primary.withValues(alpha: 0.15),
          child: Text(
            initial,
            style: TextStyle(color: primary, fontWeight: FontWeight.w800),
          ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),

              const SizedBox(height: 3),

              Text(
                '${profile.active ? 'Active' : 'Inactive'}'
                ' • $enabledCount modules'
                ' • ${profile.id}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall,
              ),

              const SizedBox(height: 10),

              // Accent colour preview.
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: primary,
                      borderRadius: BorderRadius.circular(4),
                      border: Border.all(color: theme.dividerColor),
                    ),
                  ),

                  const SizedBox(width: 8),

                  Text(
                    profile.primaryColorHex,
                    style: theme.textTheme.labelSmall,
                  ),
                ],
              ),

              if (hasBusinessDetails) ...[
                const SizedBox(height: 12),

                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    if (whatsapp.isNotEmpty)
                      _DetailLabel(
                        icon: Icons.chat_bubble_outline,
                        text: whatsapp,
                      ),

                    if (mobileMoneyNumber.isNotEmpty)
                      _DetailLabel(
                        icon: Icons.payments_outlined,
                        text: [
                          if (mobileMoneyName.isNotEmpty) mobileMoneyName,
                          mobileMoneyNumber,
                        ].join(' · '),
                      ),

                    if (registrationNumber.isNotEmpty)
                      _DetailLabel(
                        icon: Icons.verified_outlined,
                        text: registrationNumber,
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ],
    );

    final actions = Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.end,
      children: [
        FilledButton.tonalIcon(
          onPressed: onBranding,
          icon: const Icon(Icons.palette_outlined, size: 18),
          label: const Text('Branding'),
        ),

        OutlinedButton.icon(
          onPressed: onEdit,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Profile'),
        ),
      ],
    );

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 600;

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  identity,
                  const SizedBox(height: 16),
                  Align(alignment: Alignment.centerRight, child: actions),
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: identity),
                const SizedBox(width: 16),
                actions,
              ],
            );
          },
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────
// Public business detail
// ─────────────────────────────────────────────

class _DetailLabel extends StatelessWidget {
  const _DetailLabel({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: theme.colorScheme.onSurfaceVariant),

        const SizedBox(width: 5),

        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────
// Error state
// ─────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, textAlign: TextAlign.center),

            const SizedBox(height: 12),

            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
