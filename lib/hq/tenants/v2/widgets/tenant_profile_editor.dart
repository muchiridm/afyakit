// lib/hq/tenants/v2/widgets/tenant_profile_editor.dart
import 'package:afyakit/hq/tenants/v2/controller/tenant_profile_controller.dart';
import 'package:afyakit/hq/tenants/v2/models/tenant_profile.dart';
import 'package:afyakit/hq/tenants/v2/extensions/tenant_status_x.dart';
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
  late TextEditingController _primaryColor;
  late TextEditingController _tagline;
  late TextEditingController _website;
  late TextEditingController _email;
  late TextEditingController _whatsapp;
  late TextEditingController _registrationNumber;

  // NEW: mobile money
  late TextEditingController _mmName;
  late TextEditingController _mmAccount;
  late TextEditingController _mmNumber;

  String _currency = 'KES';
  bool _featureCatalog = false;
  bool _featureLabs = false;

  @override
  void initState() {
    super.initState();
    final p = widget.initial;

    _displayName = TextEditingController(text: p?.displayName ?? '');
    _primaryColor = TextEditingController(
      text: p?.primaryColorHex ?? '#2196F3',
    );

    _tagline = TextEditingController(text: p?.details.tagline ?? '');
    _website = TextEditingController(text: p?.details.website ?? '');
    _email = TextEditingController(text: p?.details.email ?? '');
    _whatsapp = TextEditingController(text: p?.details.whatsapp ?? '');

    _registrationNumber = TextEditingController(
      text:
          p?.details.compliance['registrationNumber'] as String? ??
          p?.details.compliance['regNumber'] as String? ??
          '',
    );

    // read mobile money from payments if present
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
    _featureCatalog = p?.features.enabled('catalog') ?? false;
    _featureLabs = p?.features.enabled('labs') ?? false;
  }

  @override
  void dispose() {
    _displayName.dispose();
    _primaryColor.dispose();
    _tagline.dispose();
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
                        ? 'Create Tenant Profile'
                        : 'Edit Tenant Profile',
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
                const SizedBox(height: 12),
              ],

              _text('Display name', _displayName, required: true),
              _text('Primary color hex', _primaryColor, hint: '#2196F3'),
              _text('Tagline', _tagline),
              _text('Website', _website),
              _text('Email', _email),
              _text('WhatsApp', _whatsapp),
              _text('Registration number', _registrationNumber),

              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _currency,
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

              const SizedBox(height: 20),
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
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Catalog'),
                value: _featureCatalog,
                onChanged: (v) => setState(() => _featureCatalog = v),
              ),
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

    final ok = await ref
        .read(tenantProfileControllerProvider.notifier)
        .save(
          slug: widget.initial?.id,
          displayName: _displayName.text.trim(),
          primaryColorHex: _primaryColor.text.trim().isEmpty
              ? '#2196F3'
              : _primaryColor.text.trim(),
          features: {'catalog': _featureCatalog, 'labs': _featureLabs},
          profile: {
            'tagline': _tagline.text.trim(),
            'website': _website.text.trim(),
            'email': _email.text.trim(),
            'whatsapp': _whatsapp.text.trim(),
            'currency': _currency,
            if (compliance.isNotEmpty) 'compliance': compliance,
            if (payments.isNotEmpty) 'payments': payments,
          },
          status: widget.initial?.status ?? TenantStatus.active,
        );

    if (ok && mounted) Navigator.of(context).maybePop();
  }
}
