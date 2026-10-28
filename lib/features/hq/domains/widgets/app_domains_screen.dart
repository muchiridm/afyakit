// lib/features/hq/apps/domains/widgets/app_domains_screen.dart

import 'package:afyakit/features/hq/domains/controllers/app_domains_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/core/domains/models/domain_binding.dart';

class AppDomainsScreen extends ConsumerWidget {
  const AppDomainsScreen({
    super.key,
    required this.tenantId,
    required this.app,
  });

  final String tenantId;
  final AppProfile app;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cleanTenantId = tenantId.trim().toLowerCase();

    final cleanAppId = app.id.trim().toLowerCase();

    final scope = (tenantId: cleanTenantId, appId: cleanAppId);

    final state = ref.watch(appDomainsControllerProvider(scope));

    final ctrl = ref.read(appDomainsControllerProvider(scope).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Domains & CORS · ${app.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.busy || state.loading ? null : ctrl.reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: state.busy
            ? null
            : () async {
                final domain = await _promptDomain(context);

                if (domain != null && domain.trim().isNotEmpty) {
                  await ctrl.addDomain(domain);
                }
              },
        icon: const Icon(Icons.add),
        label: const Text('Add domain'),
      ),
      body: AbsorbPointer(
        absorbing: state.busy,
        child: RefreshIndicator(
          onRefresh: ctrl.reload,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _AppContextCard(tenantId: cleanTenantId, app: app),

              const SizedBox(height: 16),

              const _CorsInfoCard(),

              const SizedBox(height: 16),

              if (state.loading) ...[
                const SizedBox(height: 80),
                const Center(child: CircularProgressIndicator()),
              ] else ...[
                if (state.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      state.error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),

                if (state.domains.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 48),
                    child: Center(
                      child: Text('No domains yet. Tap “Add domain”.'),
                    ),
                  )
                else
                  ...state.domains.map((domain) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DomainCard(
                        binding: domain,
                        onCopyToken:
                            domain.pendingVerification &&
                                domain.dnsToken != null
                            ? () {
                                ctrl.copy(domain.dnsToken!);
                              }
                            : null,
                        onVerify: domain.pendingVerification
                            ? () {
                                ctrl.verifyDomain(domain.domain);
                              }
                            : null,
                        onMakePrimary: domain.verified && !domain.isPrimary
                            ? () {
                                ctrl.setPrimary(domain.domain);
                              }
                            : null,
                        onToggleActive: (value) {
                          ctrl.setActive(domain.domain, value);
                        },
                        onRemove: () async {
                          final ok = await _confirm(
                            context,
                            title: 'Remove domain?',
                            message:
                                'Remove ${domain.domain} '
                                'from ${app.displayName}?',
                            confirmLabel: 'Remove',
                          );

                          if (ok == true) {
                            await ctrl.removeDomain(domain.domain);
                          }
                        },
                      ),
                    );
                  }),
              ],

              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppContextCard extends StatelessWidget {
  const _AppContextCard({required this.tenantId, required this.app});

  final String tenantId;
  final AppProfile app;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: app.primaryColor.withValues(alpha: 0.12),
              child: Text(
                app.displayName.trim().isNotEmpty
                    ? app.displayName.trim()[0].toUpperCase()
                    : '?',
                style: TextStyle(
                  color: app.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.displayName,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text('App ID: ${app.id}', style: theme.textTheme.bodySmall),
                  Text(
                    'Data tenant: $tenantId',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CorsInfoCard extends StatelessWidget {
  const _CorsInfoCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CORS allowlist rules',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            const Text(
              'A domain is allowed for CORS only when:\n'
              '• Active = ON\n'
              '• Verified = YES\n\n'
              'If either is false, browsers will still block '
              'cross-origin requests.',
            ),
          ],
        ),
      ),
    );
  }
}

class _DomainCard extends StatelessWidget {
  const _DomainCard({
    required this.binding,
    required this.onToggleActive,
    required this.onRemove,
    this.onVerify,
    this.onMakePrimary,
    this.onCopyToken,
  });

  final DomainBinding binding;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onRemove;
  final VoidCallback? onVerify;
  final VoidCallback? onMakePrimary;
  final VoidCallback? onCopyToken;

  @override
  Widget build(BuildContext context) {
    final eligible = binding.corsEligible;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    binding.domain,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (binding.isPrimary)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.blueGrey.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Text('Primary'),
                  ),
              ],
            ),

            const SizedBox(height: 8),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _pill(
                  context,
                  label: binding.verified ? 'Verified' : 'Not verified',
                  ok: binding.verified,
                ),
                _pill(
                  context,
                  label: binding.active ? 'Active' : 'Inactive',
                  ok: binding.active,
                ),
                _pill(
                  context,
                  label: eligible ? 'CORS OK' : 'CORS blocked',
                  ok: eligible,
                ),
              ],
            ),

            if (binding.pendingVerification && binding.dnsToken != null) ...[
              const SizedBox(height: 12),
              Text(
                'TXT token (add to DNS):',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: SelectableText(
                      binding.dnsToken!,
                      style: const TextStyle(fontFamily: 'monospace'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: onCopyToken,
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copy'),
                  ),
                ],
              ),
            ],

            const SizedBox(height: 12),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Switch(value: binding.active, onChanged: onToggleActive),
                    const SizedBox(width: 4),
                    const Text('Allow CORS'),
                  ],
                ),

                if (onVerify != null)
                  OutlinedButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verify'),
                  ),

                if (onMakePrimary != null)
                  OutlinedButton.icon(
                    onPressed: onMakePrimary,
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Make primary'),
                  ),

                TextButton(onPressed: onRemove, child: const Text('Remove')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _pill(
    BuildContext context, {
    required String label,
    required bool ok,
  }) {
    final color = ok ? Colors.green : Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.20)),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

Future<String?> _promptDomain(BuildContext context) async {
  final controller = TextEditingController();

  String? result;

  await showDialog<void>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Add domain'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            hintText: 'e.g. www.dawapap.com',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              result = controller.text.trim();

              Navigator.of(dialogContext).pop();
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );

  controller.dispose();

  return result;
}

Future<bool?> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
}) {
  return showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
}
