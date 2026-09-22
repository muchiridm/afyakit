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

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final ok = await ref.read(appProfileControllerProvider.notifier).save();

    if (ok && mounted) Navigator.of(context).maybePop();
  }

  Future<void> _confirmDelete() async {
    final initial = ref.read(appProfileControllerProvider).initial;
    if (initial == null) return;

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete app'),
            content: Text(
              'Delete "${initial.displayName}"?\n\n'
              'This removes the app profile only. '
              'The tenant and its shared data are not deleted.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;

    if (!confirmed) return;

    final ok = await ref.read(appProfileControllerProvider.notifier).delete();

    if (ok && mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(appProfileControllerProvider);
    final controller = ref.read(appProfileControllerProvider.notifier);
    final tenant = state.tenant;

    if (tenant == null) {
      return const Center(child: CircularProgressIndicator());
    }

    final modules = FeatureRegistry.features.where(
      (feature) => feature.key != FeatureKeys.hq,
    );

    return SafeArea(
      top: false,
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: AbsorbPointer(
          absorbing: state.busy,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 760),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              state.isCreate ? 'Create app' : 'Edit app',
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                          ),
                          Chip(label: Text('Tenant: ${tenant.id}')),
                          IconButton(
                            tooltip: 'Close',
                            onPressed: () => Navigator.of(context).maybePop(),
                            icon: const Icon(Icons.close),
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          const _SectionTitle('Identity'),
                          _field(
                            controller.appId,
                            'App ID',
                            enabled: state.isCreate,
                            required: state.isCreate,
                          ),
                          _field(
                            controller.displayName,
                            'Display name',
                            required: true,
                          ),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('App active'),
                            value: state.active,
                            onChanged: controller.setActive,
                          ),

                          const _SectionTitle('Public profile'),
                          _field(controller.tagline, 'Tagline'),
                          _field(
                            controller.website,
                            'Website',
                            keyboardType: TextInputType.url,
                          ),
                          _field(
                            controller.email,
                            'Email',
                            keyboardType: TextInputType.emailAddress,
                          ),
                          _field(
                            controller.whatsapp,
                            'WhatsApp number',
                            keyboardType: TextInputType.phone,
                          ),
                          _field(
                            controller.supportNote,
                            'Support note',
                            maxLines: 2,
                          ),

                          const _SectionTitle('Payments'),
                          _field(
                            controller.mobileMoneyName,
                            'Mobile-money label',
                            hint: 'M-Pesa Till',
                          ),
                          _field(
                            controller.mobileMoneyNumber,
                            'Till / Paybill number',
                            keyboardType: TextInputType.phone,
                          ),
                          _field(
                            controller.mobileMoneyAccount,
                            'Payment account / reference',
                          ),

                          const _SectionTitle('Compliance'),
                          _field(
                            controller.registrationNumber,
                            'Registration number',
                          ),

                          const _SectionTitle('Web / SEO'),
                          _field(controller.seoTitle, 'Browser tab title'),
                          _field(
                            controller.seoDescription,
                            'Meta description',
                            maxLines: 3,
                          ),

                          const _SectionTitle('Modules'),
                          Text(
                            'Enabled modules must be allowed by '
                            'tenant "${tenant.id}".',
                          ),
                          const SizedBox(height: 8),
                          for (final module in modules)
                            Builder(
                              builder: (context) {
                                final allowed = controller.tenantAllows(
                                  module.key,
                                );

                                return SwitchListTile(
                                  contentPadding: EdgeInsets.zero,
                                  title: Text(module.label),
                                  subtitle: Text(
                                    allowed
                                        ? (module.description
                                                      ?.trim()
                                                      .isNotEmpty ==
                                                  true
                                              ? module.description!
                                              : 'Available to this app.')
                                        : 'Not enabled for the parent tenant.',
                                  ),
                                  value:
                                      allowed &&
                                      state.features[module.key] == true,
                                  onChanged: allowed
                                      ? (value) => controller.setFeature(
                                          module.key,
                                          value,
                                        )
                                      : null,
                                );
                              },
                            ),

                          if (state.error != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              state.error!,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                              ),
                            ),
                          ],

                          if (!state.isCreate) ...[
                            const Divider(height: 32),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton.icon(
                                onPressed: _confirmDelete,
                                icon: const Icon(Icons.delete_forever),
                                label: const Text('Delete app'),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: state.busy ? null : _save,
                          icon: state.busy
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.save),
                          label: Text(
                            state.isCreate ? 'Create app' : 'Save profile',
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 20, 0, 12),
      child: Text(title, style: Theme.of(context).textTheme.titleMedium),
    );
  }
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool enabled = true,
  bool required = false,
  String? hint,
  int maxLines = 1,
  TextInputType? keyboardType,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      validator: required
          ? (value) => value == null || value.trim().isEmpty
                ? '$label is required'
                : null
          : null,
    ),
  );
}
