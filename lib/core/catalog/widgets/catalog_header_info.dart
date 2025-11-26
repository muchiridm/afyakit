// lib/core/catalog/widgets/catalog_header_info.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/hq/tenants/models/tenant_profile.dart';

class CatalogHeaderInfo extends ConsumerWidget {
  final VoidCallback? onLogin;
  final bool centered;

  const CatalogHeaderInfo({super.key, this.onLogin, this.centered = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    final labelStyle = theme.textTheme.bodySmall?.copyWith(
      color: theme.colorScheme.onSurface.withOpacity(0.65),
      fontWeight: FontWeight.w500,
      letterSpacing: -0.05,
    );
    final valueStyle = theme.textTheme.bodyMedium?.copyWith(
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.05,
    );

    final asyncProfile = ref.watch(tenantProfileProvider);

    String? whatsapp;
    String? mobileMoneyName;
    String? mobileMoneyNumber;
    String? registrationNumber;

    asyncProfile.whenOrNull(
      data: (TenantProfile p) {
        final d = p.details;

        String? clean(String? v) {
          final t = v?.trim();
          return (t == null || t.isEmpty) ? null : t;
        }

        whatsapp = clean(d.whatsapp);
        mobileMoneyName = clean(d.mobileMoneyName);
        mobileMoneyNumber = clean(d.mobileMoneyNumber);
        registrationNumber = clean(d.registrationNumber);
      },
    );

    final infoItems = <Widget>[];

    // WhatsApp row (tap → copy number)
    if (whatsapp != null) {
      infoItems.add(
        _InfoItem(
          icon: Icons.chat_bubble_outline,
          label: 'WhatsApp',
          value: whatsapp!,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    // Mobile money row only if both name + number present
    if (mobileMoneyName != null && mobileMoneyNumber != null) {
      infoItems.add(
        _InfoItem(
          icon: Icons.payments_rounded,
          label: mobileMoneyName!,
          value: mobileMoneyNumber!,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    // Registration number row only if present
    if (registrationNumber != null) {
      infoItems.add(
        _InfoItem(
          icon: Icons.verified_rounded,
          label: 'Reg. No.',
          value: registrationNumber!,
          labelStyle: labelStyle,
          valueStyle: valueStyle,
        ),
      );
    }

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        FilledButton.tonal(
          onPressed: onLogin,
          child: const Text('Login / Register'),
        ),
        const SizedBox(height: 14),
        if (infoItems.isNotEmpty)
          Wrap(
            spacing: 16,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: centered ? WrapAlignment.center : WrapAlignment.end,
            children: infoItems,
          ),
      ],
    );
  }
}

class _InfoItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final TextStyle? labelStyle;
  final TextStyle? valueStyle;

  const _InfoItem({
    required this.icon,
    required this.label,
    required this.value,
    this.labelStyle,
    this.valueStyle,
  });

  @override
  Widget build(BuildContext context) {
    final tooltipMessage = switch (label) {
      'WhatsApp' => 'Copy WhatsApp number',
      _ => 'Copy $label',
    };

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: tooltipMessage,
                preferBelow: false, // show above the value
                verticalOffset: 8,
                child: GestureDetector(
                  onTap: () => _copyToClipboard(context, value, label),
                  child: Text(value, style: valueStyle),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ───────────────────────── helpers ─────────────────────────

void _copyToClipboard(BuildContext context, String text, String label) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label copied'),
      duration: const Duration(seconds: 1),
    ),
  );
}
