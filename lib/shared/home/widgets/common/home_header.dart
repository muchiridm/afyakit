// lib/shared/home/widgets/common/home_header.dart

import 'package:afyakit/core/auth/widgets/logout_button.dart';
import 'package:afyakit/core/tenancy/providers/tenant_profile_providers.dart';
import 'package:afyakit/features/inventory/records/deliveries/widgets/delivery_banner.dart';
import 'package:afyakit/shared/home/widgets/common/catalog_button.dart';
import 'package:afyakit/shared/home/widgets/common/home_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth_user/widgets/user_badge.dart';
import '../../models/home_mode.dart';

class HomeHeader extends ConsumerWidget {
  const HomeHeader({
    super.key,
    required this.mode,
    this.greetingName,
    this.memberId,
    this.showDeliveryBanner = false,
    this.panelWidth = 380,
  });

  final HomeMode mode;

  /// Member-only greeting bits (pass null for staff)
  final String? greetingName;
  final String? memberId;

  /// Staff-only extras
  final bool showDeliveryBanner;

  /// Desired width for the “card column”
  final double panelWidth;

  bool get _isMember => mode == HomeMode.member;

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
        wrapPanel(HomeCard(child: _HeaderCardContent(title: tenantName))),
        if (_isMember) ...[
          const SizedBox(height: 10),
          wrapPanel(_MemberGreeting(name: greetingName, memberId: memberId)),
        ],
        if (showDeliveryBanner) ...[
          const SizedBox(height: 8),
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
        final maxW = c.maxWidth;

        // Tight is where "Catalog + Badge + Logout" can start squeezing.
        final tight = maxW < 340;

        final titleStyle = theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w900,
        );

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Row 1: Title (highest)
            Text(
              title,
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: titleStyle,
            ),

            const SizedBox(height: 8),

            // ── Row 2: Catalog | UserBadge | Logout (same level)
            Row(
              children: [
                // Left: Catalog
                const CatalogButton(),

                const SizedBox(width: 10),

                // Center: Badge, but must shrink safely (no overflow)
                Expanded(
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.center,
                      child: const UserBadge(),
                    ),
                  ),
                ),

                const SizedBox(width: 10),

                // Right: Logout
                LogoutButton(dense: tight),
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
