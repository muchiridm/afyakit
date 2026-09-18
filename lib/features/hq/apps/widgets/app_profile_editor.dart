// lib/features/hq/apps/widgets/app_profile_editor.dart

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/capabilities/feature_keys.dart';
import 'package:afyakit/core/capabilities/feature_registry.dart';
import 'package:afyakit/features/hq/apps/controllers/app_profile_controller.dart';

class AppProfileEditor extends ConsumerStatefulWidget {
  const AppProfileEditor({super.key});

  @override
  ConsumerState<AppProfileEditor> createState() => _AppProfileEditorState();
}

class _AppProfileEditorState extends ConsumerState<AppProfileEditor> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProfileControllerProvider);

    final controller = ref.read(appProfileControllerProvider.notifier);

    final tenant = state.tenant;

    if (tenant == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final modules = FeatureRegistry.features
        .where((feature) => feature.key != FeatureKeys.hq)
        .toList(growable: false);

    return AbsorbPointer(
      absorbing: state.busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _EditorHeader(
                isCreate: state.isCreate,
                active: state.active,
                tenantId: tenant.id,
              ),

              const SizedBox(height: 20),

              _SectionTitle(
                title: 'App identity',
                description:
                    'Define the product identity for this app. '
                    'It will use the shared "${tenant.id}" '
                    'tenant data universe.',
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: controller.appId,
                enabled: state.isCreate,
                decoration: const InputDecoration(
                  labelText: 'App ID',
                  hintText: 'dawapap',
                  helperText:
                      'Stable technical product ID. '
                      'It cannot be changed after creation.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (!state.isCreate) {
                    return null;
                  }

                  if (value == null || value.trim().isEmpty) {
                    return 'App ID is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 12),

              TextFormField(
                controller: controller.displayName,
                decoration: const InputDecoration(
                  labelText: 'Display name',
                  hintText: 'DawaPap',
                  helperText: 'Client-facing product name.',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Display name is required';
                  }

                  return null;
                },
              ),

              const SizedBox(height: 8),

              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('App active'),
                subtitle: const Text(
                  'Inactive apps cannot bootstrap or be used by clients.',
                ),
                value: state.active,
                onChanged: controller.setActive,
              ),

              const Divider(height: 36),

              const _SectionTitle(
                title: 'App details',
                description:
                    'Product-specific public contact and support information.',
              ),

              const SizedBox(height: 12),

              _textField(controller: controller.website, label: 'Website'),

              _textField(controller: controller.email, label: 'Email'),

              _textField(
                controller: controller.supportNote,
                label: 'Support note',
                maxLines: 2,
              ),

              const Divider(height: 36),

              _SectionTitle(
                title: 'App modules',
                description:
                    'Choose which capabilities this product exposes. '
                    'The "${tenant.id}" tenant defines the maximum '
                    'capabilities available to its apps.',
              ),

              const SizedBox(height: 12),

              for (final module in modules)
                Builder(
                  builder: (context) {
                    final allowed = controller.tenantAllows(module.key);

                    final enabled =
                        allowed && state.features[module.key] == true;

                    return SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(module.label),
                      subtitle: allowed
                          ? ((module.description ?? '').trim().isEmpty
                                ? const Text('Available to this app.')
                                : Text(module.description!.trim()))
                          : const Text(
                              'Unavailable: this capability '
                              'is not enabled for the parent tenant.',
                            ),
                      value: enabled,
                      onChanged: allowed
                          ? (value) {
                              controller.setFeature(module.key, value);
                            }
                          : null,
                    );
                  },
                ),

              if (state.error != null) ...[
                const SizedBox(height: 16),
                Text(state.error!, style: const TextStyle(color: Colors.red)),
              ],

              const SizedBox(height: 24),

              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: state.busy ? null : _save,
                  icon: state.busy
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save),
                  label: Text(state.isCreate ? 'Create app' : 'Save app'),
                ),
              ),

              if (!state.isCreate) ...[
                const SizedBox(height: 24),
                const Divider(),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: state.busy ? null : _confirmDelete,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete app'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
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

    final ok = await ref.read(appProfileControllerProvider.notifier).save();

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirmDelete() async {
    final state = ref.read(appProfileControllerProvider);

    final initial = state.initial;

    if (initial == null) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) {
            return AlertDialog(
              title: const Text('Delete app'),
              content: Text(
                'Delete "${initial.displayName}"?\n\n'
                'This removes the app profile only. '
                'The tenant and its shared data are not deleted.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.red),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
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

    final ok = await ref.read(appProfileControllerProvider.notifier).delete();

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }
}

class _EditorHeader extends StatelessWidget {
  const _EditorHeader({
    required this.isCreate,
    required this.active,
    required this.tenantId,
  });

  final bool isCreate;
  final bool active;
  final String tenantId;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                isCreate ? 'Create app' : 'Edit app',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Data tenant: $tenantId',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (!isCreate) Chip(label: Text(active ? 'Active' : 'Inactive')),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.description});

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 4),
        Text(description, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

Widget _textField({
  required TextEditingController controller,
  required String label,
  int maxLines = 1,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      maxLines: maxLines,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    ),
  );
}
