// lib/core/catalog/widgets/catalog_components/catalog_header.dart

import 'dart:ui' show lerpDouble;

import 'package:afyakit/modules/core/auth_users/guards/require_auth.dart';
import 'package:afyakit/modules/core/auth_users/providers/current_user_providers.dart';
import 'package:afyakit/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/hq/branding/providers/tenant_logo_providers.dart';
import 'package:afyakit/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/shared/widgets/home_screens/tenant_home_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class CatalogHeader extends ConsumerWidget {
  final String selectedForm;
  final ValueChanged<String> onFormChanged;

  final int? quoteItemCount;
  final String? quoteTotalLabel; // formatted total e.g. "KES 9,147"
  final VoidCallback? onViewQuote;

  const CatalogHeader({
    super.key,
    required this.selectedForm,
    required this.onFormChanged,
    this.quoteItemCount,
    this.quoteTotalLabel,
    this.onViewQuote,
  });

  static const double _bp = 820;

  static double _responsiveGap(double w) {
    const minG = 6.0;
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

    final Widget logo = (logoUrl == null)
        ? const SizedBox(height: 90)
        : Image.network(logoUrl, height: 90, fit: BoxFit.contain);

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.dividerColor.withOpacity(0.35),
            width: 0.5,
          ),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
        child: isNarrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  SizedBox(height: 90, child: Center(child: logo)),
                  const SizedBox(height: 8),
                  _HeaderButtons(
                    quoteItemCount: quoteItemCount,
                    quoteTotalLabel: quoteTotalLabel,
                    onViewQuote: onViewQuote,
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
                  SizedBox(width: 240, height: 90, child: Center(child: logo)),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: _HeaderButtons(
                        quoteItemCount: quoteItemCount,
                        quoteTotalLabel: quoteTotalLabel,
                        onViewQuote: onViewQuote,
                        onLogin: () async => requireAuth(context, ref),
                        centered: false,
                        horizontal: false,
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

// ───────────────────── left: contact info ─────────────────────

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

    final items = <Widget>[];

    if (whatsapp != null) {
      items.add(
        _ContactItem(
          icon: Icons.chat_bubble_outline,
          label: 'WhatsApp',
          value: whatsapp!,
        ),
      );
    }

    if (mobileMoneyName != null && mobileMoneyNumber != null) {
      items.add(
        _ContactItem(
          icon: Icons.payments_rounded,
          label: mobileMoneyName!,
          value: mobileMoneyNumber!,
        ),
      );
    }

    if (registrationNumber != null) {
      items.add(
        _ContactItem(
          icon: Icons.verified_rounded,
          label: 'Reg. No.',
          value: registrationNumber!,
        ),
      );
    }

    if (items.isEmpty) return const SizedBox.shrink();

    if (horizontalLayout) {
      final align = centered ? WrapAlignment.center : WrapAlignment.start;
      return Wrap(
        spacing: 16,
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
          Padding(padding: const EdgeInsets.only(bottom: 2), child: w),
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
      fontSize: (baseLabel.fontSize ?? 11) + 1,
      color: theme.colorScheme.onSurface.withOpacity(0.7),
      fontWeight: FontWeight.w500,
    );

    final valueStyle = baseValue?.copyWith(
      fontSize: (baseValue.fontSize ?? 12) + 1,
      color: theme.colorScheme.onSurface,
      fontWeight: FontWeight.w600,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
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

// ───────────────────── right: buttons ─────────────────────

class _HeaderButtons extends ConsumerWidget {
  final int? quoteItemCount;
  final String? quoteTotalLabel;
  final VoidCallback? onViewQuote;
  final VoidCallback? onLogin;
  final bool centered;
  final bool horizontal;

  const _HeaderButtons({
    required this.centered,
    required this.horizontal,
    this.quoteItemCount,
    this.quoteTotalLabel,
    this.onViewQuote,
    this.onLogin,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final userAsync = ref.watch(currentUserProvider);
    final user = userAsync.value;

    final count = quoteItemCount ?? 0;
    final canViewCart = onViewQuote != null && count > 0;

    // Cart label
    String cartLabel() {
      if (count <= 0) return 'Cart';
      final total = quoteTotalLabel;
      return total == null || total.isEmpty
          ? 'Cart ($count)'
          : 'Cart ($count) · $total';
    }

    // ─────────────────────────────────────────────
    // 1. USER SIGNED IN → show HOME button
    // ─────────────────────────────────────────────
    final homeButton = user != null
        ? FilledButton.tonalIcon(
            icon: const Icon(Icons.home_outlined),
            label: const Text('Home'),
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => const TenantHomeShell()),
              );
            },
          )
        : null;

    // ─────────────────────────────────────────────
    // 2. USER NOT SIGNED IN → show Login/Register
    // ─────────────────────────────────────────────
    final loginButton = (user == null && onLogin != null)
        ? FilledButton.tonal(
            onPressed: onLogin,
            child: const Text('Login / Register'),
          )
        : null;

    // ─────────────────────────────────────────────
    // Compose children in order:
    // Home (if logged in)
    // Cart (if any)
    // Login (if not logged in)
    // ─────────────────────────────────────────────
    final children = <Widget>[
      if (homeButton != null) homeButton,
      if (onViewQuote != null)
        FilledButton.icon(
          onPressed: canViewCart ? onViewQuote : null,
          icon: const Icon(Icons.shopping_cart_outlined),
          label: Text(cartLabel()),
        ),
      if (loginButton != null) loginButton,
    ];

    if (children.isEmpty) return const SizedBox.shrink();

    // Horizontal layout for narrow screens
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

    // Vertical layout for wide screens
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
