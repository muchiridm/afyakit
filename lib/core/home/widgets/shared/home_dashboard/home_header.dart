// lib/core/home/widgets/shared/home_dashboard/home_header.dart

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/auth_user/widgets/user_badge.dart';
import 'package:afyakit/core/auth/shared/widgets/auth_button.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/home/widgets/shared/home_shell.dart';
import 'package:afyakit/core/hq/branding/widgets/tenant_brand_logo.dart';
import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_banner.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    super.key,
    required this.entry,
    this.greetingName,
    this.memberId,
    this.showDeliveryBanner = false,

    /// Use this on catalog pages.
    ///
    /// When logged in:
    /// - true  => show Home button above Logout
    /// - false => show UserBadge above Logout
    ///
    /// When logged out:
    /// - Home/UserBadge is suppressed
    /// - AuthButton shows Login
    this.showHomeButton = false,

    /// Use false on the LoginScreen so the page can reuse the shared
    /// brand/contact/logo header without showing a duplicate Login button.
    this.showIdentityActions = true,
  });

  final EntryMode entry;
  final String? greetingName;
  final String? memberId;
  final bool showDeliveryBanner;
  final bool showHomeButton;
  final bool showIdentityActions;

  bool get _isMemberUx => entry != EntryMode.staff;

  static const double _bp = 860;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);
    final width = MediaQuery.of(context).size.width;
    final isNarrow = width < _bp;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BrandHeaderBar(
          fallbackLabel: tenantName,
          isNarrow: isNarrow,
          showHomeButton: showHomeButton,
          showIdentityActions: showIdentityActions,
        ),
        if (_isMemberUx) ...[
          const SizedBox(height: AppShape.gap10),
          _MemberGreeting(name: greetingName, memberId: memberId),
        ],
        if (showDeliveryBanner) ...[
          const SizedBox(height: AppShape.gap8),
          const DeliveryBanner(),
        ],
      ],
    );
  }
}

class _BrandHeaderBar extends StatelessWidget {
  const _BrandHeaderBar({
    required this.fallbackLabel,
    required this.isNarrow,
    required this.showHomeButton,
    required this.showIdentityActions,
  });

  final String fallbackLabel;
  final bool isNarrow;
  final bool showHomeButton;
  final bool showIdentityActions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final logo = TenantBrandLogo(
      height: isNarrow ? 82 : 88,
      maxWidth: 220,
      fallbackLabel: fallbackLabel,
    );

    return DecoratedBox(
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
                  if (showIdentityActions) ...[
                    const SizedBox(height: AppShape.gap8),
                    _HeaderIdentityActions(
                      showHomeButton: showHomeButton,
                      centered: true,
                    ),
                  ],
                  const SizedBox(height: AppShape.gap12),
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
                      child: showIdentityActions
                          ? _HeaderIdentityActions(
                              showHomeButton: showHomeButton,
                              centered: false,
                            )
                          : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _HeaderContact extends ConsumerWidget {
  const _HeaderContact({
    required this.centered,
    required this.horizontalLayout,
  });

  final bool centered;
  final bool horizontalLayout;

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
          return t == null || t.isEmpty ? null : t;
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
        for (final item in items)
          Padding(padding: const EdgeInsets.only(bottom: 3), child: item),
      ],
    );
  }
}

class _ContactItem extends StatelessWidget {
  const _ContactItem({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final baseLabel = theme.textTheme.labelSmall;
    final baseValue = theme.textTheme.bodySmall;

    final labelStyle = baseLabel?.copyWith(
      fontSize: baseLabel.fontSize ?? 11,
      color: theme.colorScheme.onSurface.withOpacity(0.62),
      fontWeight: FontWeight.w500,
    );

    final valueStyle = baseValue?.copyWith(
      fontSize: baseValue.fontSize ?? 12,
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

class _HeaderIdentityActions extends ConsumerWidget {
  const _HeaderIdentityActions({
    required this.showHomeButton,
    required this.centered,
  });

  final bool showHomeButton;
  final bool centered;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    final user = sessionAsync.maybeWhen(data: (u) => u, orElse: () => null);

    final isLoggedIn = user != null;

    final shouldShowHomeButton = showHomeButton && isLoggedIn;
    final shouldShowUserBadge = !showHomeButton && isLoggedIn;

    final crossAxisAlignment = centered
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.end;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: crossAxisAlignment,
      children: [
        if (shouldShowHomeButton)
          FilledButton.tonalIcon(
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
        else if (shouldShowUserBadge)
          const UserBadge(),

        if (shouldShowHomeButton || shouldShowUserBadge)
          const SizedBox(height: AppShape.gap8),

        const AuthButton(loginLabel: 'Login', logoutLabel: 'Logout'),
      ],
    );
  }
}

class _MemberGreeting extends StatelessWidget {
  const _MemberGreeting({required this.name, required this.memberId});

  final String? name;
  final String? memberId;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final n = (name ?? '').trim();
    if (n.isEmpty) return const SizedBox.shrink();

    final id = (memberId ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $n 👋',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (id.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Member ID: $id',
            style: theme.textTheme.bodySmall?.copyWith(color: theme.hintColor),
          ),
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
