// lib/core/hq/domains/widgets/tenant_domains_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/core/hq/domains/controllers/tenant_domains_controller.dart';
import 'package:afyakit/core/hq/domains/models/domain_binding.dart';

class TenantDomainsScreen extends ConsumerWidget {
  const TenantDomainsScreen({super.key, required this.initial});

  final TenantProfile initial;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final slug = initial.id.trim().toLowerCase();
    final state = ref.watch(tenantDomainsControllerProvider(slug));
    final ctrl = ref.read(tenantDomainsControllerProvider(slug).notifier);

    return Scaffold(
      appBar: AppBar(
        title: Text('Domains & CORS · ${initial.displayName}'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: state.busy || state.loading ? null : () => ctrl.reload(),
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
          onRefresh: () async => ctrl.reload(),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _CorsInfoCard(),
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
                  ...state.domains.map(
                    (d) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _DomainCard(
                        binding: d,
                        onCopyToken: d.pendingVerification && d.dnsToken != null
                            ? () => ctrl.copy(d.dnsToken!)
                            : null,
                        onVerify: d.pendingVerification
                            ? () => ctrl.verifyDomain(d.domain)
                            : null,
                        onMakePrimary: d.verified && !d.isPrimary
                            ? () => ctrl.setPrimary(d.domain)
                            : null,
                        onToggleActive: (v) => ctrl.setActive(d.domain, v),
                        onRemove: () async {
                          final ok = await _confirm(
                            context,
                            title: 'Remove domain?',
                            message:
                                'Remove ${d.domain} from ${initial.displayName}?',
                            confirmLabel: 'Remove',
                          );
                          if (ok == true) await ctrl.removeDomain(d.domain);
                        },
                      ),
                    ),
                  ),
              ],
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }
}

class _CorsInfoCard extends StatelessWidget {
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
              'If either is false, browsers will still block cross-origin requests.',
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
                      color: Colors.blueGrey.withOpacity(0.10),
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
            Row(
              children: [
                Switch(value: binding.active, onChanged: onToggleActive),
                const SizedBox(width: 8),
                const Text('Allow CORS'),
                const Spacer(),
                if (onVerify != null)
                  OutlinedButton.icon(
                    onPressed: onVerify,
                    icon: const Icon(Icons.verified, size: 16),
                    label: const Text('Verify'),
                  ),
                if (onMakePrimary != null) ...[
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: onMakePrimary,
                    icon: const Icon(Icons.star, size: 16),
                    label: const Text('Make primary'),
                  ),
                ],
                const SizedBox(width: 8),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: (ok ? Colors.green : Colors.red).withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: (ok ? Colors.green : Colors.red).withOpacity(0.2),
        ),
      ),
      child: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}

Future<String?> _promptDomain(BuildContext context) async {
  final ctrl = TextEditingController();
  String? result;

  await showDialog<void>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Add domain'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(
            hintText: 'e.g. www.dawapap.com',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              result = ctrl.text.trim();
              Navigator.of(ctx).pop();
            },
            child: const Text('Add'),
          ),
        ],
      );
    },
  );

  ctrl.dispose();
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
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
}
