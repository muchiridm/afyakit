// lib/core/home/widgets/components/home_header.dart

import 'package:afyakit/core/auth/shared/widgets/auth_button.dart';
import 'package:afyakit/core/home/enums/entry_mode.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_profile_providers.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_banner.dart';
import 'package:afyakit/core/home/widgets/shared/dashboard/catalog_button.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/widgets/user_badge.dart';
import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    super.key,
    required this.entry,
    this.greetingName,
    this.memberId,
    this.showDeliveryBanner = false,
    this.panelWidth = 380,
  });

  /// Who is this user in this tenant?
  final EntryMode entry;

  /// Member/guest greeting (optional)
  final String? greetingName;

  /// Member ID (optional)
  final String? memberId;

  /// Staff-only: show delivery banner
  final bool showDeliveryBanner;

  /// Max width for the header panels
  final double panelWidth;

  bool get _isMemberUx => entry != EntryMode.staff;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tenantName = ref.watch(tenantDisplayNameProvider);

    Widget wrapPanel(Widget child) {
      return Align(
        alignment: Alignment.centerLeft,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: panelWidth),
          child: child,
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        wrapPanel(AppCard(child: _HeaderCardContent(title: tenantName))),
        if (_isMemberUx) ...[
          const SizedBox(height: AppShape.gap10),
          wrapPanel(_MemberGreeting(name: greetingName, memberId: memberId)),
        ],
        if (showDeliveryBanner) ...[
          const SizedBox(height: AppShape.gap8),
          wrapPanel(const DeliveryBanner()),
        ],
      ],
    );
  }
}

class _HeaderCardContent extends StatelessWidget {
  const _HeaderCardContent({required this.title});
  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return LayoutBuilder(
      builder: (context, c) {
        final tight = c.maxWidth < 340;

        final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),
            const SizedBox(height: AppShape.gap8),
            Row(
              children: [
                const CatalogButton(),
                const SizedBox(width: AppShape.gap10),
                const Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: UserBadge(),
                    ),
                  ),
                ),
                const SizedBox(width: AppShape.gap10),

                // ✅ Smart button: Logout when signed-in; Login/Register when guest.
                AuthButton(dense: tight),
              ],
            ),
          ],
        );
      },
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
