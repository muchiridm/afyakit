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
    final initial = ref.read(appProfileControllerProvider).initial;

    if (initial == null) {
      return;
    }

    final confirmed =
        await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: const Text('Delete app'),
            content: Text(
              'Delete "${initial.displayName}"?\n\n'
              'This removes the app profile and '
              'its app-owned Zoho configuration. '
              'The tenant and its shared data are '
              'not deleted.',
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

    if (!confirmed) {
      return;
    }

    final ok = await ref.read(appProfileControllerProvider.notifier).delete();

    if (ok && mounted) {
      Navigator.of(context).maybePop();
    }
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
                    // ─────────────────────────────
                    // Header
                    // ─────────────────────────────
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

                    // ─────────────────────────────
                    // Form body
                    // ─────────────────────────────
                    Expanded(
                      child: ListView(
                        padding: const EdgeInsets.all(16),
                        children: [
                          // ───────────────────────
                          // Identity
                          // ───────────────────────
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

                          // ───────────────────────
                          // Public profile
                          // ───────────────────────
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

                          // ───────────────────────
                          // Payments
                          // ───────────────────────
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

                          // ───────────────────────
                          // Compliance
                          // ───────────────────────
                          const _SectionTitle('Compliance'),

                          _field(
                            controller.registrationNumber,
                            'Registration number',
                          ),

                          // ───────────────────────
                          // Web / SEO
                          // ───────────────────────
                          const _SectionTitle('Web / SEO'),

                          _field(controller.seoTitle, 'Browser tab title'),

                          _field(
                            controller.seoDescription,
                            'Meta description',
                            maxLines: 3,
                          ),

                          // ───────────────────────
                          // Zoho Books
                          // ───────────────────────
                          const _SectionTitle('Zoho Books'),

                          if (state.isCreate)
                            const _InfoBox(
                              icon: Icons.info_outline,
                              text:
                                  'Create the app first, then reopen '
                                  'its profile to configure Zoho Books.',
                            )
                          else ...[
                            _ZohoStatusPanel(
                              state: state,
                              onRefresh: controller.reloadZoho,
                            ),

                            const SizedBox(height: 12),

                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Enable Zoho Books'),
                              subtitle: Text(
                                state.zohoCredentialConfigured
                                    ? 'Zoho credential is available.'
                                    : 'Credential not found in Secret Manager.',
                              ),
                              value: state.zohoEnabled,
                              onChanged: state.zohoLoading
                                  ? null
                                  : (value) => controller.setZohoEnabled(value),
                            ),

                            _field(
                              controller.zohoOrganisationId,
                              'Zoho organisation ID',
                              enabled: !state.zohoLoading,
                              required: state.zohoEnabled,
                              hint: 'e.g. 705213400000...',
                              onChanged: (_) => controller.markZohoDirty(),
                            ),

                            if (!state.zohoCredentialConfigured)
                              const _InfoBox(
                                icon: Icons.key_off_outlined,
                                text:
                                    'The refresh token stays in '
                                    'Secret Manager. Configure the '
                                    'credential for this app, then '
                                    'press Refresh to re-check it.',
                              ),

                            if (state.zohoError != null) ...[
                              const SizedBox(height: 8),
                              _ErrorBox(message: state.zohoError!),
                            ],
                          ],

                          // ───────────────────────
                          // Modules
                          // ───────────────────────
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

                          // ───────────────────────
                          // General error
                          // ───────────────────────
                          if (state.error != null) ...[
                            const SizedBox(height: 12),
                            _ErrorBox(message: state.error!),
                          ],

                          // ───────────────────────
                          // Delete
                          // ───────────────────────
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

                    // ─────────────────────────────
                    // Save
                    // ─────────────────────────────
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

// ═════════════════════════════════════════════
// Zoho status
// ═════════════════════════════════════════════

class _ZohoStatusPanel extends StatelessWidget {
  const _ZohoStatusPanel({required this.state, required this.onRefresh});

  final AppProfileState state;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (state.zohoLoading) {
      return const Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Row(
            children: [
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              SizedBox(width: 12),
              Text('Loading Zoho Books configuration…'),
            ],
          ),
        ),
      );
    }

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _StatusChip(
                        label: state.zohoExists
                            ? 'Configured'
                            : 'Not configured',
                        ok: state.zohoExists,
                      ),
                      _StatusChip(
                        label: state.zohoCredentialConfigured
                            ? 'Credential found'
                            : 'Credential missing',
                        ok: state.zohoCredentialConfigured,
                      ),
                      _StatusChip(
                        label: state.zohoReady ? 'Ready' : 'Not ready',
                        ok: state.zohoReady,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh Zoho status',
                  onPressed: onRefresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),

            const SizedBox(height: 12),

            Text(
              'Connection ID: '
              '${state.zohoConnectionId.isEmpty ? '—' : state.zohoConnectionId}',
              style: theme.textTheme.bodySmall,
            ),

            const SizedBox(height: 4),

            Text(
              'Credential reference: '
              '${state.zohoCredentialRef.isEmpty ? '—' : state.zohoCredentialRef}',
              style: theme.textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.label, required this.ok});

  final String label;
  final bool ok;

  @override
  Widget build(BuildContext context) {
    return Chip(
      avatar: Icon(
        ok ? Icons.check_circle_outline : Icons.error_outline,
        size: 17,
      ),
      label: Text(label),
    );
  }
}

// ═════════════════════════════════════════════
// Informational boxes
// ═════════════════════════════════════════════

class _InfoBox extends StatelessWidget {
  const _InfoBox({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: colors.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: Theme.of(context).textTheme.bodySmall),
          ),
        ],
      ),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colors.errorContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: colors.onErrorContainer),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: TextStyle(color: colors.onErrorContainer),
            ),
          ),
        ],
      ),
    );
  }
}

// ═════════════════════════════════════════════
// Generic section title
// ═════════════════════════════════════════════

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

// ═════════════════════════════════════════════
// Generic text field
// ═════════════════════════════════════════════

Widget _field(
  TextEditingController controller,
  String label, {
  bool enabled = true,
  bool required = false,
  String? hint,
  int maxLines = 1,
  TextInputType? keyboardType,
  ValueChanged<String>? onChanged,
}) {
  return Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: controller,
      enabled: enabled,
      maxLines: maxLines,
      keyboardType: keyboardType,
      onChanged: onChanged,
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
