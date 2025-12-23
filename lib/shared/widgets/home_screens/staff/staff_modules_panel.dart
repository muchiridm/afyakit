import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/models/feature_registry.dart';
import 'package:afyakit/core/tenancy/providers/tenant_feature_providers.dart';
import 'package:afyakit/shared/services/snack_service.dart';

class StaffModulesPanel extends ConsumerWidget {
  const StaffModulesPanel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1) Registry: simple list of module defs (inventory, retail, etc.)
    final modules = FeatureRegistry.modules;

    // 2) Only enabled modules
    final enabled = modules
        .where((m) => ref.watch(isModuleEnabledProvider(m.key)))
        .toList();

    if (enabled.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Modules', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: enabled.map((m) => _ModuleTile(module: m)).toList(),
        ),
      ],
    );
  }
}

class _ModuleTile extends ConsumerWidget {
  const _ModuleTile({required this.module});

  final ModuleDef module;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 220, maxWidth: 360),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          final entry = module.entry;
          if (entry == null) {
            SnackService.showError('🚧 ${module.label} is not wired yet.');
            return;
          }
          Navigator.of(context).push(MaterialPageRoute(builder: entry));
        },
        child: Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(module.icon),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        module.label,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                    const Icon(Icons.chevron_right),
                  ],
                ),
                if ((module.description ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    module.description!.trim(),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
