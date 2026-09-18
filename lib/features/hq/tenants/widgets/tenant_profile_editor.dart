// lib/features/hq/tenants/widgets/tenant_profile_editor.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/capabilities/feature_registry.dart';
import 'package:afyakit/features/hq/tenants/controllers/tenant_profile_controller.dart';

import 'tenant_profile_editor_sections.dart';

class TenantProfileEditor extends ConsumerStatefulWidget {
  const TenantProfileEditor({super.key});

  @override
  ConsumerState<TenantProfileEditor> createState() =>
      _TenantProfileEditorState();
}

class _TenantProfileEditorState extends ConsumerState<TenantProfileEditor> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantProfileControllerProvider);

    final controller = ref.read(tenantProfileControllerProvider.notifier);

    final initial = state.initial;

    return AbsorbPointer(
      absorbing: state.busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TenantProfileEditorHeader(initial: initial),

              const SizedBox(height: 20),

              // ─────────────────────────────────
              // Tenant identity
              // ─────────────────────────────────
              Text(
                'Tenant',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 4),

              Text(
                'The tenant is an internal data and capability boundary. '
                'Product identity and branding belong to apps.',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: controller.tenantId,
                enabled: state.isCreate,
                decoration: const InputDecoration(
                  labelText: 'Tenant ID',
                  hintText: 'afya',
                  helperText:
                      'Stable internal identifier. '
                      'It cannot be changed after creation.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (!state.isCreate) {
                    return null;
                  }

                  final tenantId = value?.trim() ?? '';

                  if (tenantId.isEmpty) {
                    return 'Tenant ID is required';
                  }

                  if (!RegExp(
                    r'^[a-z0-9][a-z0-9_-]*$',
                  ).hasMatch(tenantId.toLowerCase())) {
                    return 'Use lowercase letters, numbers, hyphens or underscores';
                  }

                  return null;
                },
              ),

              const Divider(height: 36),

              // ─────────────────────────────────
              // Capability ceiling
              // ─────────────────────────────────
              Text(
                'Tenant capabilities',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
              ),

              const SizedBox(height: 4),

              Text(
                'These are the maximum capabilities available within this '
                'tenant. Apps can expose only a subset of them.',
                style: Theme.of(context).textTheme.bodySmall,
              ),

              const SizedBox(height: 12),

              FeatureTogglesSection(
                modules: FeatureRegistry.features,
                values: state.features,
                onChanged: controller.setFeature,
                title: null,
              ),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(state.error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),

              TenantProfileSaveBar(
                busy: state.busy,
                isCreate: state.isCreate,
                onSave: _save,
              ),

              if (!state.isCreate && initial != null) ...[
                const SizedBox(height: 24),
                const Divider(),
                TenantProfileDeleteBar(
                  busy: state.busy,
                  displayName: initial.id,
                  onDelete: _confirmAndDelete,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final ok = await ref.read(tenantProfileControllerProvider.notifier).save();

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirmAndDelete() async {
    final state = ref.read(tenantProfileControllerProvider);

    final initial = state.initial;

    if (initial == null) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete tenant'),
              content: Text(
                'Delete tenant "${initial.id}"?\n\n'
                'This is the shared data universe for its apps. '
                'Only continue if the tenant is no longer required.',
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false);
                  },
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true);
                  },
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        ) ??
        false;

    if (!confirmed) {
      return;
    }

    final ok = await ref
        .read(tenantProfileControllerProvider.notifier)
        .delete();

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }
}
