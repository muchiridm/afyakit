// lib/core/hq/tenants/widgets/tenant_profile_editor_sections.dart

import 'package:afyakit/core/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/core/hq/tenants/models/feature_registry.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:flutter/material.dart';

class TenantProfileEditorHeader extends StatelessWidget {
  const TenantProfileEditorHeader({
    super.key,
    required this.initial,
    required this.primaryColorHex,
  });

  final TenantProfile? initial;
  final String primaryColorHex;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Row(
      children: [
        Text(
          initial == null ? 'Create tenant profile' : 'Edit tenant profile',
          style: t.textTheme.titleMedium,
        ),
        const Spacer(),
        if (initial != null)
          Chip(
            label: Text(initial!.status.value),
            backgroundColor: initial!.isActive
                ? Colors.green.withOpacity(0.12)
                : Colors.red.withOpacity(0.12),
            labelStyle: TextStyle(
              color: initial!.isActive ? Colors.green : Colors.red,
            ),
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
      ],
    );
  }
}

class TenantProfilePublicSection extends StatelessWidget {
  const TenantProfilePublicSection({
    super.key,
    required this.displayName,
    required this.website,
    required this.email,
    required this.whatsapp,
    required this.registrationNumber,
  });

  final TextEditingController displayName;
  final TextEditingController website;
  final TextEditingController email;
  final TextEditingController whatsapp;
  final TextEditingController registrationNumber;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _text('Display name', displayName, required: true),
        const SizedBox(height: 8),
        Text('Public profile', style: t.textTheme.titleSmall),
        const SizedBox(height: 6),
        _text('Website', website),
        _text('Email', email),
        _text('WhatsApp', whatsapp),
        _text('Registration number', registrationNumber),
      ],
    );
  }
}

class CurrencyPicker extends StatelessWidget {
  const CurrencyPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return DropdownButtonFormField<String>(
      initialValue: value,
      decoration: const InputDecoration(
        labelText: 'Currency',
        border: OutlineInputBorder(),
      ),
      items: const [
        DropdownMenuItem(value: 'KES', child: Text('KES')),
        DropdownMenuItem(value: 'USD', child: Text('USD')),
        DropdownMenuItem(value: 'SOS', child: Text('SOS')),
      ],
      onChanged: (v) => onChanged(v ?? 'KES'),
    );
  }
}

class TenantProfileMobileMoneySection extends StatelessWidget {
  const TenantProfileMobileMoneySection({
    super.key,
    required this.mmName,
    required this.mmAccount,
    required this.mmNumber,
  });

  final TextEditingController mmName;
  final TextEditingController mmAccount;
  final TextEditingController mmNumber;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Mobile money', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        _text('Mobile money name', mmName),
        _text('Mobile money account', mmAccount),
        _text('Mobile money number', mmNumber),
      ],
    );
  }
}

class TenantProfileAccountNumberingSection extends StatelessWidget {
  const TenantProfileAccountNumberingSection({
    super.key,
    required this.accountFormat,
  });

  final TextEditingController accountFormat;

  static const _allowed = <String>{'yymm_seq4', 'yymm_seq5', 'yymm_seq6'};

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Account numbering', style: t.textTheme.titleSmall),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: TextFormField(
            controller: accountFormat,
            decoration: const InputDecoration(
              labelText: 'Account format',
              hintText: 'yymm_seq4',
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              final s = (v ?? '').trim();
              if (s.isEmpty) return null;
              if (!_allowed.contains(s)) {
                return 'Use: yymm_seq4 / yymm_seq5 / yymm_seq6';
              }
              return null;
            },
          ),
        ),
        Text(
          'Example: yymm_seq4 → 26020001',
          style: t.textTheme.bodySmall?.copyWith(color: Colors.grey),
        ),
      ],
    );
  }
}

class FeatureTogglesSection extends StatelessWidget {
  const FeatureTogglesSection({
    super.key,
    required this.modules,
    required this.values,
    required this.onChanged,
  });

  final List<FeatureDef> modules;
  final Map<String, bool> values;
  final void Function(String key, bool value) onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Module groups',
          style: Theme.of(
            context,
          ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        for (final m in modules)
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(m.label),
            subtitle: (m.description ?? '').trim().isEmpty
                ? null
                : Text(m.description!.trim()),
            value: values[m.key] == true,
            onChanged: (v) => onChanged(m.key, v),
          ),
      ],
    );
  }
}

class TenantProfileSaveBar extends StatelessWidget {
  const TenantProfileSaveBar({
    super.key,
    required this.busy,
    required this.isCreate,
    required this.onSave,
  });

  final bool busy;
  final bool isCreate;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: busy ? null : onSave,
        icon: busy
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.save),
        label: Text(isCreate ? 'Create' : 'Save'),
      ),
    );
  }
}

class TenantProfileDeleteBar extends StatelessWidget {
  const TenantProfileDeleteBar({
    super.key,
    required this.busy,
    required this.displayName,
    required this.onDelete,
  });

  final bool busy;
  final String displayName;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: TextButton.icon(
        onPressed: busy ? null : onDelete,
        icon: const Icon(Icons.delete_forever),
        label: const Text('Delete tenant'),
        style: TextButton.styleFrom(foregroundColor: Colors.red),
      ),
    );
  }
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
