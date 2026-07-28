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

enum _HeaderLayout { small, medium, wide }

class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    super.key,
    required this.entry,
    this.greetingName,
    this.memberId,
    this.showDeliveryBanner = false,
    this.showHomeButton = false,
    this.showIdentityActions = true,
    this.centerContent = false,
  });

  final EntryMode entry;
  final String? greetingName;
  final String? memberId;
  final bool showDeliveryBanner;
  final bool showHomeButton;
  final bool showIdentityActions;
  final bool centerContent;

  bool get _isMemberUx => entry != EntryMode.staff;

  static const double _mediumBreakpoint = 700;
  static const double _wideBreakpoint = 1100;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tenantName = ref.watch(tenantDisplayNameProvider);
    final double width = MediaQuery.sizeOf(context).width;

    final _HeaderLayout layout = switch (width) {
      < _mediumBreakpoint => _HeaderLayout.small,
      < _wideBreakpoint => _HeaderLayout.medium,
      _ => _HeaderLayout.wide,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _BrandHeaderBar(
          fallbackLabel: tenantName,
          layout: layout,
          showHomeButton: showHomeButton,
          showIdentityActions: showIdentityActions,
        ),
        if (_isMemberUx) ...[
          const SizedBox(height: AppShape.gap10),
          _MemberGreeting(
            name: greetingName,
            memberId: memberId,
            centered: centerContent,
          ),
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
    required this.layout,
    required this.showHomeButton,
    required this.showIdentityActions,
  });

  final String fallbackLabel;
  final _HeaderLayout layout;
  final bool showHomeButton;
  final bool showIdentityActions;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final bool isWide = layout == _HeaderLayout.wide;

    final Widget logo = TenantBrandLogo(
      height: isWide ? 88 : 82,
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
        padding: EdgeInsets.fromLTRB(16, isWide ? 10 : 12, 16, 8),
        child: switch (layout) {
          _HeaderLayout.small => _SmallHeaderLayout(
            logo: logo,
            showHomeButton: showHomeButton,
            showIdentityActions: showIdentityActions,
          ),
          _HeaderLayout.medium => _MediumHeaderLayout(
            logo: logo,
            showHomeButton: showHomeButton,
            showIdentityActions: showIdentityActions,
          ),
          _HeaderLayout.wide => _WideHeaderLayout(
            logo: logo,
            showHomeButton: showHomeButton,
            showIdentityActions: showIdentityActions,
          ),
        },
      ),
    );
  }
}

class _SmallHeaderLayout extends StatelessWidget {
  const _SmallHeaderLayout({
    required this.logo,
    required this.showHomeButton,
    required this.showIdentityActions,
  });

  final Widget logo;
  final bool showHomeButton;
  final bool showIdentityActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        SizedBox(height: 86, child: Center(child: logo)),

        if (showIdentityActions) ...[
          const SizedBox(height: AppShape.gap8),
          _HeaderIdentityActions(
            showHomeButton: showHomeButton,
            centered: true,
            horizontal: true,
          ),
        ],

        const SizedBox(height: AppShape.gap12),

        const _HeaderContact(centered: true, horizontalLayout: true),
      ],
    );
  }
}

class _MediumHeaderLayout extends StatelessWidget {
  const _MediumHeaderLayout({
    required this.logo,
    required this.showHomeButton,
    required this.showIdentityActions,
  });

  final Widget logo;
  final bool showHomeButton;
  final bool showIdentityActions;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 96,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: showIdentityActions
                      ? _HeaderHomeAction(showHomeButton: showHomeButton)
                      : const SizedBox.shrink(),
                ),
              ),

              const SizedBox(width: 32),

              SizedBox(width: 220, height: 96, child: Center(child: logo)),

              const SizedBox(width: 32),

              Expanded(
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: showIdentityActions
                      ? const AuthButton(
                          loginLabel: 'Login',
                          logoutLabel: 'Logout',
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: AppShape.gap8),

        const _HeaderContact(centered: true, horizontalLayout: true),
      ],
    );
  }
}

class _WideHeaderLayout extends StatelessWidget {
  const _WideHeaderLayout({
    required this.logo,
    required this.showHomeButton,
    required this.showIdentityActions,
  });

  final Widget logo;
  final bool showHomeButton;
  final bool showIdentityActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        const Expanded(
          child: Align(
            alignment: Alignment.centerLeft,
            child: _HeaderContact(centered: false, horizontalLayout: false),
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
                    horizontal: false,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
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
    final AsyncValue<TenantProfile> asyncProfile = ref.watch(
      tenantProfileProvider,
    );

    String? whatsapp;
    String? mobileMoneyName;
    String? mobileMoneyNumber;
    String? registrationNumber;

    asyncProfile.whenOrNull(
      data: (TenantProfile profile) {
        final details = profile.details;

        String? clean(String? value) {
          final String? trimmed = value?.trim();

          return trimmed == null || trimmed.isEmpty ? null : trimmed;
        }

        whatsapp = clean(details.whatsapp);
        mobileMoneyName = clean(details.mobileMoneyName);
        mobileMoneyNumber = clean(details.mobileMoneyNumber);
        registrationNumber = clean(details.registrationNumber);
      },
    );

    final List<Widget> items = [
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

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    if (horizontalLayout) {
      return Wrap(
        spacing: 14,
        runSpacing: 6,
        alignment: centered ? WrapAlignment.center : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: items,
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        for (final Widget item in items)
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
    final ThemeData theme = Theme.of(context);

    final TextStyle? labelStyle = theme.textTheme.labelSmall?.copyWith(
      fontSize: theme.textTheme.labelSmall?.fontSize ?? 11,
      color: theme.colorScheme.onSurface.withOpacity(0.62),
      fontWeight: FontWeight.w500,
    );

    final TextStyle? valueStyle = theme.textTheme.bodySmall?.copyWith(
      fontSize: theme.textTheme.bodySmall?.fontSize ?? 12,
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
    required this.horizontal,
  });

  final bool showHomeButton;
  final bool centered;
  final bool horizontal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tenantId = ref.watch(tenantIdProvider);
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    final user = sessionAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    final bool isLoggedIn = user != null;
    final bool shouldShowHomeButton = showHomeButton && isLoggedIn;
    final bool shouldShowUserBadge = !showHomeButton && isLoggedIn;

    final Widget? primaryAction;

    if (shouldShowHomeButton) {
      primaryAction = const _HomeButton();
    } else if (shouldShowUserBadge) {
      primaryAction = const UserBadge();
    } else {
      primaryAction = null;
    }

    const Widget authAction = AuthButton(
      loginLabel: 'Login',
      logoutLabel: 'Logout',
    );

    if (horizontal) {
      return Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: AppShape.gap8,
        runSpacing: AppShape.gap8,
        children: [if (primaryAction != null) primaryAction, authAction],
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.end,
      children: [
        if (primaryAction != null) ...[
          primaryAction,
          const SizedBox(height: AppShape.gap8),
        ],
        authAction,
      ],
    );
  }
}

class _HeaderHomeAction extends ConsumerWidget {
  const _HeaderHomeAction({required this.showHomeButton});

  final bool showHomeButton;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String tenantId = ref.watch(tenantIdProvider);
    final sessionAsync = ref.watch(sessionControllerProvider(tenantId));

    final user = sessionAsync.maybeWhen(
      data: (value) => value,
      orElse: () => null,
    );

    if (!showHomeButton || user == null) {
      return const SizedBox.shrink();
    }

    return const _HomeButton();
  }
}

class _HomeButton extends StatelessWidget {
  const _HomeButton();

  @override
  Widget build(BuildContext context) {
    return FilledButton.tonalIcon(
      icon: const Icon(Icons.home_outlined, size: 18),
      label: const Text('Home'),
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      ),
      onPressed: () {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute<void>(builder: (_) => const HomeShell()),
        );
      },
    );
  }
}

class _MemberGreeting extends StatelessWidget {
  const _MemberGreeting({
    required this.name,
    required this.memberId,
    required this.centered,
  });

  final String? name;
  final String? memberId;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);

    final String cleanName = (name ?? '').trim();

    if (cleanName.isEmpty) {
      return const SizedBox.shrink();
    }

    final String cleanMemberId = (memberId ?? '').trim();

    return Column(
      crossAxisAlignment: centered
          ? CrossAxisAlignment.center
          : CrossAxisAlignment.start,
      children: [
        Text(
          'Hi, $cleanName 👋',
          textAlign: centered ? TextAlign.center : TextAlign.start,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        if (cleanMemberId.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            'Member ID: $cleanMemberId',
            textAlign: centered ? TextAlign.center : TextAlign.start,
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
