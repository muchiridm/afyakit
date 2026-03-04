// lib/core/app_hq/tenants/widgets/tenant_profile_editor.dart

import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/controllers/tenant_profile_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    final ctrl = ref.read(tenantProfileControllerProvider.notifier);

    final initial = state.initial; // controller source of truth

    return AbsorbPointer(
      absorbing: state.busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TenantProfileEditorHeader(
                initial: initial,
                primaryColorHex: state.primaryColorHex,
              ),
              const SizedBox(height: 12),

              // ───────────────────────── Public / contact ─────────────────────────
              TenantProfilePublicSection(
                displayName: ctrl.displayName,
                website: ctrl.website,
                email: ctrl.email,
                whatsapp: ctrl.whatsapp,
                registrationNumber: ctrl.registrationNumber,
              ),

              const SizedBox(height: 12),
              CurrencyPicker(
                value: state.currency,
                onChanged: ctrl.setCurrency,
              ),

              const SizedBox(height: 16),

              // ───────────────────────── Mobile money ─────────────────────────
              TenantProfileMobileMoneySection(
                mmName: ctrl.mmName,
                mmAccount: ctrl.mmAccount,
                mmNumber: ctrl.mmNumber,
              ),

              const SizedBox(height: 16),

              // ───────────────────────── Account numbering policy ─────────────────────────
              TenantProfileAccountNumberingSection(
                accountPrefix: ctrl.accountPrefix,
                accountPad: ctrl.accountPad,
              ),

              const SizedBox(height: 16),

              // ───────────────────────── Feature toggles ─────────────────────────
              Row(
                children: [
                  Text(
                    'Modules',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (state.unknownFeatureKeys.isNotEmpty)
                    TextButton(
                      onPressed: ctrl.toggleShowUnknown,
                      child: Text(
                        state.showUnknown
                            ? 'Hide legacy (${state.unknownFeatureKeys.length})'
                            : 'Show legacy (${state.unknownFeatureKeys.length})',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              FeatureTogglesSection(
                modules: FeatureRegistry.features,
                values: state.features,
                onChanged: ctrl.setFeature,
              ),

              if (state.showUnknown && state.unknownFeatureKeys.isNotEmpty) ...[
                const SizedBox(height: 8),
                LegacyKeysSection(
                  keys: state.unknownFeatureKeys,
                  values: state.features,
                  onChanged: ctrl.setFeature,
                ),
              ],

              const SizedBox(height: 16),

              // ───────────────────────── Error ─────────────────────────
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              // ───────────────────────── Save / Delete ─────────────────────────
              TenantProfileSaveBar(
                busy: state.busy,
                isCreate: state.isCreate,
                onSave: _save,
              ),

              const SizedBox(height: 24),

              if (!state.isCreate && initial != null)
                TenantProfileDeleteBar(
                  busy: state.busy,
                  displayName: initial.displayName,
                  onDelete: _confirmAndDelete,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    final ok = await ref.read(tenantProfileControllerProvider.notifier).save();
    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirmAndDelete() async {
    final state = ref.read(tenantProfileControllerProvider);
    final initial = state.initial;
    if (initial == null) return;

    final confirmed =
        (await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Delete tenant'),
            content: Text(
              'Are you sure you want to delete "${initial.displayName}"?\n\n'
              'This action may be irreversible depending on server settings.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Delete'),
              ),
            ],
          ),
        )) ??
        false;

    if (!confirmed) return;

    final ok = await ref
        .read(tenantProfileControllerProvider.notifier)
        .delete();
    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }
}
