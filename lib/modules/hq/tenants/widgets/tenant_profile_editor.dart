// lib/hq/tenants/widgets/tenant_profile_editor.dart

import 'package:afyakit/modules/hq/tenants/controllers/tenant_profile_controller.dart';
import 'package:afyakit/core/tenancy/models/feature_keys.dart';
import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class TenantProfileEditor extends ConsumerStatefulWidget {
  const TenantProfileEditor({super.key, this.initial});

  final TenantProfile? initial;

  @override
  ConsumerState<TenantProfileEditor> createState() =>
      _TenantProfileEditorState();
}

class _TenantProfileEditorState extends ConsumerState<TenantProfileEditor> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _displayName;

  // public / contact details
  late TextEditingController _website;
  late TextEditingController _email;
  late TextEditingController _whatsapp;
  late TextEditingController _registrationNumber;

  // mobile money
  late TextEditingController _mmName;
  late TextEditingController _mmAccount;
  late TextEditingController _mmNumber;

  // brand color is *owned* by the branding screen; here we just preserve it
  late String _primaryColorHex;

  String _currency = 'KES';

  // feature toggles
  bool _featureRetailCatalog = false;
  bool _featureLabs = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;

    _displayName = TextEditingController(text: p?.displayName ?? '');

    _primaryColorHex = p?.primaryColorHex ?? '#2196F3';

    _website = TextEditingController(text: p?.details.website ?? '');
    _email = TextEditingController(text: p?.details.email ?? '');
    _whatsapp = TextEditingController(text: p?.details.whatsapp ?? '');

    _registrationNumber = TextEditingController(
      text:
          p?.details.compliance['registrationNumber'] as String? ??
          p?.details.compliance['regNumber'] as String? ??
          '',
    );

    final payments = p?.details.payments ?? const <String, dynamic>{};
    _mmName = TextEditingController(
      text: payments['mobileMoneyName'] as String? ?? '',
    );
    _mmAccount = TextEditingController(
      text: payments['mobileMoneyAccount'] as String? ?? '',
    );
    _mmNumber = TextEditingController(
      text: payments['mobileMoneyNumber'] as String? ?? '',
    );

    _currency = p?.details.currency ?? 'KES';

    // ─────────────────────────────────────────
    // Feature flags (new keys + legacy fallback)
    // ─────────────────────────────────────────
    final featuresMap = p?.features.features ?? const <String, bool>{};

    // Treat any of: retail, retail.catalog, or legacy "catalog" as enabling retail catalog
    final hasRetailCatalog =
        (featuresMap[FeatureKeys.retailCatalog] ?? false) ||
        (featuresMap[FeatureKeys.retail] ?? false) ||
        (featuresMap['catalog'] ?? false);

    _featureRetailCatalog = hasRetailCatalog;
    _featureLabs = p?.features.enabled(FeatureKeys.labs) ?? false;
  }

  @override
  void dispose() {
    _displayName.dispose();

    _website.dispose();
    _email.dispose();
    _whatsapp.dispose();
    _registrationNumber.dispose();

    _mmName.dispose();
    _mmAccount.dispose();
    _mmNumber.dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(tenantProfileControllerProvider);
    final initial = widget.initial;

    return AbsorbPointer(
      absorbing: state.busy,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(
                    initial == null
                        ? 'Create tenant profile'
                        : 'Edit tenant profile',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Spacer(),
                  if (initial != null)
                    Chip(
                      label: Text(initial.status.value),
                      backgroundColor: initial.isActive
                          ? Colors.green.withOpacity(0.12)
                          : Colors.red.withOpacity(0.12),
                      labelStyle: TextStyle(
                        color: initial.isActive ? Colors.green : Colors.red,
                      ),
                      visualDensity: VisualDensity.compact,
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                ],
              ),
              const SizedBox(height: 12),

              if (initial != null) ...[
                Text(
                  'ID (slug): ${initial.id}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Brand color: $_primaryColorHex '
                  '(change under “Branding”)',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.grey[700]),
                ),
                const SizedBox(height: 12),
              ],

              // ─────────────────────────────────────────────
              // Basic identity
              // ─────────────────────────────────────────────
              _text('Display name', _displayName, required: true),

              const SizedBox(height: 8),
              Text(
                'Public profile',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 4),

              _text('Website', _website),
              _text('Email', _email),
              _text('WhatsApp', _whatsapp),
              _text('Registration number', _registrationNumber),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                decoration: const InputDecoration(
                  labelText: 'Currency',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'KES', child: Text('KES')),
                  DropdownMenuItem(value: 'USD', child: Text('USD')),
                  DropdownMenuItem(value: 'SOS', child: Text('SOS')),
                ],
                onChanged: (v) => setState(() => _currency = v ?? 'KES'),
              ),

              const SizedBox(height: 16),
              Text(
                'Mobile money',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              _text('Mobile money name', _mmName),
              _text('Mobile money account', _mmAccount),
              _text('Mobile money number', _mmNumber),

              const SizedBox(height: 16),
              Text('Features', style: Theme.of(context).textTheme.titleSmall),

              // Retail / catalog feature – drives customer-facing catalog
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Retail catalog'),
                subtitle: const Text('Customer-facing catalog / retail app'),
                value: _featureRetailCatalog,
                onChanged: (v) => setState(() => _featureRetailCatalog = v),
              ),

              // Labs feature
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Labs'),
                value: _featureLabs,
                onChanged: (v) => setState(() => _featureLabs = v),
              ),

              const SizedBox(height: 16),
              if (state.error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    state.error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),

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
                  label: Text(initial == null ? 'Create' : 'Save'),
                ),
              ),

              const SizedBox(height: 24),

              if (initial != null)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: state.busy ? null : _confirmAndDelete,
                    icon: const Icon(Icons.delete_forever),
                    label: const Text('Delete tenant'),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _text(
    String label,
    TextEditingController ctrl, {
    String? hint,
    bool required = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: ctrl,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          border: const OutlineInputBorder(),
        ),
        validator: required
            ? (v) => (v == null || v.trim().isEmpty) ? 'Required' : null
            : null,
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    // compliance
    final compliance = <String, dynamic>{};
    if (_registrationNumber.text.trim().isNotEmpty) {
      compliance['registrationNumber'] = _registrationNumber.text.trim();
    }

    // payments
    final payments = <String, dynamic>{};
    if (_mmName.text.trim().isNotEmpty) {
      payments['mobileMoneyName'] = _mmName.text.trim();
    }
    if (_mmAccount.text.trim().isNotEmpty) {
      payments['mobileMoneyAccount'] = _mmAccount.text.trim();
    }
    if (_mmNumber.text.trim().isNotEmpty) {
      payments['mobileMoneyNumber'] = _mmNumber.text.trim();
    }

    // profile / details payload
    // Branding fields (tagline, seoTitle, seoDescription, primaryColorHex)
    // are owned by the Branding screen and not touched here.
    final profile = <String, dynamic>{
      'website': _website.text.trim(),
      'email': _email.text.trim(),
      'whatsapp': _whatsapp.text.trim(),
      'currency': _currency,
      if (compliance.isNotEmpty) 'compliance': compliance,
      if (payments.isNotEmpty) 'payments': payments,
    };

    // Start from existing features so we don't blow away unrelated flags.
    final existing =
        widget.initial?.features.features ?? const <String, bool>{};
    final features = Map<String, bool>.from(existing);

    // Drop legacy key
    features.remove('catalog');

    // Retail: keep both the umbrella and the specific catalog key in sync
    features[FeatureKeys.retail] = _featureRetailCatalog;
    features[FeatureKeys.retailCatalog] = _featureRetailCatalog;

    // Labs
    features[FeatureKeys.labs] = _featureLabs;

    final ok = await ref
        .read(tenantProfileControllerProvider.notifier)
        .save(
          slug: widget.initial?.id,
          displayName: _displayName.text.trim(),
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
              'Are you sure you want to delete '
              '"${initial.displayName}"?\n\n'
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
