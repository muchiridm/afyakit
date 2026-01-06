import 'package:afyakit/core/tenancy/models/feature_registry.dart';
import 'package:afyakit/features/hq/tenants/controllers/tenant_profile_controller.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'tenant_profile_editor_controllers.dart';
import 'tenant_profile_editor_sections.dart';

class TenantProfileEditor extends ConsumerStatefulWidget {
  const TenantProfileEditor({super.key, this.initial});

  final TenantProfile? initial;

  @override
  ConsumerState<TenantProfileEditor> createState() =>
      _TenantProfileEditorState();
}

class _TenantProfileEditorState extends ConsumerState<TenantProfileEditor> {
  final _formKey = GlobalKey<FormState>();

  late final TenantProfileFormControllers _c;
  late String _primaryColorHex;
  late String _currency;

  /// All feature flags we will send back.
  /// UI toggles only show registry modules, but we preserve any unknown keys.
  late Map<String, bool> _features;

  bool _showUnknown = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;

    _c = TenantProfileFormControllers.fromTenant(p);

    _primaryColorHex = p?.primaryColorHex ?? '#2196F3';
    _currency = p?.details.currency ?? 'KES';

    final existing = p?.features.features ?? const <String, bool>{};

    // Preserve existing + ensure all module keys exist.
    _features = <String, bool>{
      ...existing.map((k, v) => MapEntry(k, v == true)),
      for (final k in FeatureRegistry.keys) k: existing[k] == true,
    };
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantProfileControllerProvider);
    final initial = widget.initial;

    final unknownKeys =
        _features.keys.where((k) => FeatureRegistry.byKey(k) == null).toList()
          ..sort();

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
                primaryColorHex: _primaryColorHex,
              ),
              const SizedBox(height: 12),

              TenantProfilePublicSection(
                displayName: _c.displayName,
                website: _c.website,
                email: _c.email,
                whatsapp: _c.whatsapp,
                registrationNumber: _c.registrationNumber,
              ),

              const SizedBox(height: 12),
              CurrencyPicker(
                value: _currency,
                onChanged: (v) => setState(() => _currency = v),
              ),

              const SizedBox(height: 16),
              TenantProfileMobileMoneySection(
                mmName: _c.mmName,
                mmAccount: _c.mmAccount,
                mmNumber: _c.mmNumber,
              ),

              const SizedBox(height: 16),
              Row(
                children: [
                  Text(
                    'Modules',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  const Spacer(),
                  if (unknownKeys.isNotEmpty)
                    TextButton(
                      onPressed: () =>
                          setState(() => _showUnknown = !_showUnknown),
                      child: Text(
                        _showUnknown
                            ? 'Hide legacy (${unknownKeys.length})'
                            : 'Show legacy (${unknownKeys.length})',
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),

              ModuleTogglesSection(
                modules: FeatureRegistry.modules,
                values: _features,
                onChanged: (key, v) => setState(() => _features[key] = v),
              ),

              if (_showUnknown && unknownKeys.isNotEmpty) ...[
                const SizedBox(height: 8),
                LegacyKeysSection(
                  keys: unknownKeys,
                  values: _features,
                  onChanged: (key, v) => setState(() => _features[key] = v),
                ),
              ],

              const SizedBox(height: 16),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

              TenantProfileSaveBar(
                busy: state.busy,
                isCreate: initial == null,
                onSave: _save,
              ),

              const SizedBox(height: 24),

              if (initial != null)
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

    final compliance = <String, dynamic>{};
    final reg = _c.registrationNumber.text.trim();
    if (reg.isNotEmpty) compliance['registrationNumber'] = reg;

    final payments = <String, dynamic>{};
    final mmName = _c.mmName.text.trim();
    final mmAccount = _c.mmAccount.text.trim();
    final mmNumber = _c.mmNumber.text.trim();

    if (mmName.isNotEmpty) payments['mobileMoneyName'] = mmName;
    if (mmAccount.isNotEmpty) payments['mobileMoneyAccount'] = mmAccount;
    if (mmNumber.isNotEmpty) payments['mobileMoneyNumber'] = mmNumber;

    final profile = <String, dynamic>{
      'website': _c.website.text.trim(),
      'email': _c.email.text.trim(),
      'whatsapp': _c.whatsapp.text.trim(),
      'currency': _currency,
      if (compliance.isNotEmpty) 'compliance': compliance,
      if (payments.isNotEmpty) 'payments': payments,
    };

    // Always send boolean map; preserve unknown keys too.
    final features = <String, bool>{
      for (final e in _features.entries) e.key: e.value == true,
    };

    final ok = await ref
        .read(tenantProfileControllerProvider.notifier)
        .save(
          slug: widget.initial?.id,
          displayName: _c.displayName.text.trim(),
          primaryColorHex: _primaryColorHex,
          features: features,
          profile: profile,
          status: widget.initial?.status ?? TenantStatus.active,
        );

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _confirmAndDelete() async {
    final initial = widget.initial;
    if (initial == null) return;

    final confirmed =
        await showDialog<bool>(
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
        ) ??
        false;

    if (!confirmed) return;

    final ok = await ref
        .read(tenantProfileControllerProvider.notifier)
        .delete(initial.id);

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
  }
}
