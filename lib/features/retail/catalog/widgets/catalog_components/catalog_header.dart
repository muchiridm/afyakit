// lib/core/catalog/widgets/catalog_components/catalog_header.dart

import 'dart:ui' show lerpDouble;

import 'package:afyakit/core/auth/auth_user/guards/require_auth.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/hq/branding/providers/tenant_logo_providers.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/home/widgets/home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogHeader extends ConsumerWidget {
  final String selectedForm;
  final ValueChanged<String> onFormChanged;

  final int? quoteItemCount;
  final String? quoteTotalLabel;
  final VoidCallback? onViewQuote;
  final VoidCallback? onClearQuote;
  final VoidCallback? onExportCsv;

  const CatalogHeader({
    super.key,
    required this.selectedForm,
    required this.onFormChanged,
    this.quoteItemCount,
    this.quoteTotalLabel,
    this.onViewQuote,
    this.onClearQuote,
    this.onExportCsv,
  });

  static const double _bp = 860;

  static double _responsiveGap(double w) {
    const minG = 8.0;
    const maxG = 16.0;
    const start = 480.0;
    const end = 1440.0;
    final t = ((w - start) / (end - start)).clamp(0.0, 1.0);
    return lerpDouble(minG, maxG, t)!;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < _bp;
    final gap = _responsiveGap(width);

    final logoUrl = ref.watch(tenantPrimaryLogoUrlProvider);
    final logo = Image.network(
      logoUrl,
      height: isNarrow ? 82 : 88,
      fit: BoxFit.contain,
    );

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.28),
            width: 0.6,
          ),
        ),
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, isNarrow ? 12 : 10, 16, 8),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 86, child: Center(child: logo)),
                  const SizedBox(height: 8),
                  _HeaderButtons(
                    quoteItemCount: quoteItemCount,
                    quoteTotalLabel: quoteTotalLabel,
                    onViewQuote: onViewQuote,
                    onClearQuote: onClearQuote,
                    onExportCsv: onExportCsv,
                    onLogin: () async => requireAuth(context, ref),
                    centered: true,
                    horizontal: true,
                  ),
                  SizedBox(height: gap),
                  const _HeaderContact(centered: true, horizontalLayout: true),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _HeaderContact(
                        centered: false,
                        horizontalLayout: false,
                      ),
                    ),
                  ),
                  SizedBox(width: 220, height: 88, child: Center(child: logo)),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _HeaderButtons(
                        quoteItemCount: quoteItemCount,
                        quoteTotalLabel: quoteTotalLabel,
                        onViewQuote: onViewQuote,
                        onClearQuote: onClearQuote,
                        onExportCsv: onExportCsv,
                        onLogin: () async => requireAuth(context, ref),
                        centered: false,
                        horizontal: true,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderContact extends ConsumerWidget {
  final bool centered;
  final bool horizontalLayout;

  const _HeaderContact({
    required this.centered,
    required this.horizontalLayout,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

    final items = <Widget>[
      if (whatsapp != null)
        _ContactItem(
          icon: Icons.chat_bubble_outline,
          label: 'WhatsApp',
          value: whatsapp!,
        ),
      if (mobileMoneyName != null && mobileMoneyNumber != null)
        _ContactItem(
          icon: Icons.payments_rounded,
          label: mobileMoneyName!,
          value: mobileMoneyNumber!,
        ),
      if (registrationNumber != null)
        _ContactItem(
          icon: Icons.verified_rounded,
          label: 'Reg. No.',
          value: registrationNumber!,
        ),
    ];

    if (items.isEmpty) return const SizedBox.shrink();

    if (horizontalLayout) {
      final align = centered ? WrapAlignment.center : WrapAlignment.start;
      return Wrap(
        spacing: 14,
        runSpacing: 4,
        alignment: align,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      );
    }

    final align = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        for (final w in items)
          Padding(padding: const EdgeInsets.only(bottom: 3), child: w),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baseLabel = theme.textTheme.labelSmall;
    final baseValue = theme.textTheme.bodySmall;

    final labelStyle = baseLabel?.copyWith(
      fontSize: (baseLabel.fontSize ?? 11),
      color: theme.colorScheme.onSurface.withOpacity(0.62),
      fontWeight: FontWeight.w500,
    );

    final valueStyle = baseValue?.copyWith(
      fontSize: (baseValue.fontSize ?? 12),
      color: theme.colorScheme.onSurface.withOpacity(0.88),
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          size: 15,
          color: theme.colorScheme.onSurface.withOpacity(0.7),
        ),
        const SizedBox(width: 6),
        Text(label, style: labelStyle),
        const SizedBox(width: 6),
        MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Tooltip(
            message: 'Copy $label',
            preferBelow: false,
            verticalOffset: 8,
            child: GestureDetector(
              onTap: () => _copyToClipboard(context, value, label),
              child: Text(value, style: valueStyle),
            ),
          ),
        ),
      ],
    );
  }
}

class _HeaderButtons extends ConsumerWidget {
  final int? quoteItemCount;
  final String? quoteTotalLabel;
  final VoidCallback? onViewQuote;
  final VoidCallback? onClearQuote;
  final VoidCallback? onExportCsv;
  final VoidCallback? onLogin;
  final bool centered;
  final bool horizontal;

  const _HeaderButtons({
    required this.centered,
    required this.horizontal,
    this.quoteItemCount,
    this.quoteTotalLabel,
    this.onViewQuote,
    this.onClearQuote,
    this.onExportCsv,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    final count = quoteItemCount ?? 0;
    final canView = onViewQuote != null && count > 0;
    final canClear = onClearQuote != null && count > 0;

    String quoteLabel() {
      if (count <= 0) return 'Quote';
      final total = quoteTotalLabel;
      return total == null || total.isEmpty
          ? 'Quote ($count)'
          : 'Quote ($count) · $total';
    }

    final homeButton = user != null
        ? FilledButton.tonalIcon(
            icon: const Icon(Icons.home_outlined, size: 18),
            label: const Text('Home'),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const HomeShell()),
              );
            },
          )
        : null;

    final loginButton = (user == null && onLogin != null)
        ? FilledButton.tonal(
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            onPressed: onLogin,
            child: const Text('Login / Register'),
          )
        : null;

    final clearButton = count > 0
        ? IconButton(
            tooltip: 'Clear quote',
            visualDensity: VisualDensity.compact,
            onPressed: canClear ? onClearQuote : null,
            icon: const Icon(Icons.delete_outline),
          )
        : null;

    final quoteButton = (onViewQuote != null)
        ? FilledButton.icon(
            onPressed: canView ? onViewQuote : null,
            icon: const Icon(Icons.shopping_cart_outlined, size: 18),
            style: FilledButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            ),
            label: Text(quoteLabel(), overflow: TextOverflow.ellipsis),
          )
        : null;

    final children = <Widget>[
      if (homeButton != null) homeButton,
      if (clearButton != null) clearButton,
      if (quoteButton != null) quoteButton,
      if (loginButton != null) loginButton,
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    if (horizontal) {
      final align = centered ? WrapAlignment.center : WrapAlignment.end;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        alignment: align,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: children,
      );
    }

    final align = centered ? CrossAxisAlignment.center : CrossAxisAlignment.end;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: align,
      children: [
        children.first,
        if (children.length > 1) ...[
          const SizedBox(height: 8),
          ...children.skip(1),
        ],
      ],
    );
  }
}

void _copyToClipboard(BuildContext context, String text, String label) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('$label copied'),
      duration: const Duration(seconds: 1),
    ),
  );
}
