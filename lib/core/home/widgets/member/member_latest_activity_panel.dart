// lib/core/home/widgets/member/member_latest_activity_panel.dart

import 'package:flutter/material.dart';

import 'package:afyakit/shared/widgets/app_card.dart';
import 'package:afyakit/shared/theme/app_shape.dart';

@immutable
class MemberActivitySummary {
  const MemberActivitySummary({
    this.latestOrderLabel,
    this.latestPrescriptionLabel,
    this.latestChatLabel,
  });

  /// Example: "In delivery • #DP-10293 • 2 items"
  final String? latestOrderLabel;

  /// Example: "Amoxicillin 500mg • 2 days ago"
  final String? latestPrescriptionLabel;

  /// Example: "Last message • yesterday"
  final String? latestChatLabel;

  bool get hasAny =>
      (latestOrderLabel ?? '').trim().isNotEmpty ||
      (latestPrescriptionLabel ?? '').trim().isNotEmpty ||
      (latestChatLabel ?? '').trim().isNotEmpty;
}

class MemberLatestActivityPanel extends StatelessWidget {
  const MemberLatestActivityPanel({
    super.key,
    this.summary,
    this.onOrdersTap,
    this.onPrescriptionsTap,
    this.onChatsTap,
  });

  /// Pass this from a member-scoped provider later (tenantId+uid).
  final MemberActivitySummary? summary;

  final VoidCallback? onOrdersTap;
  final VoidCallback? onPrescriptionsTap;
  final VoidCallback? onChatsTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;

    final showEmptyHint = !(s?.hasAny ?? false);

    return AppCard(
      title: 'Your activity',
      icon: Icons.receipt_long_outlined,
      child: Column(
        children: [
          _ActivityTile(
            icon: Icons.shopping_bag_outlined,
            title: 'Orders',
            subtitle: 'Track your recent and ongoing orders.',
            trailingLabel: _cleanLabel(s?.latestOrderLabel),
            onTap: onOrdersTap ?? () => _snack(context, 'Orders (TODO)'),
          ),
          _hairlineDivider(theme),
          _ActivityTile(
            icon: Icons.receipt_long_outlined,
            title: 'Prescription history',
            subtitle: 'View prescriptions you\'ve shared or filled.',
            trailingLabel: _cleanLabel(s?.latestPrescriptionLabel),
            onTap:
                onPrescriptionsTap ??
                () => _snack(context, 'Prescription history (TODO)'),
          ),
          _hairlineDivider(theme),
          _ActivityTile(
            icon: Icons.chat_bubble_outline,
            title: 'Chats with pharmacist',
            subtitle: 'Pick up where you left off with your pharmacist.',
            trailingLabel: _cleanLabel(s?.latestChatLabel),
            onTap: onChatsTap ?? () => _snack(context, 'Chats (TODO)'),
          ),
          if (showEmptyHint) ...[
            const SizedBox(height: AppShape.gap8),
            Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'We’ll start showing your latest items here once you place an order.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.hintColor,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String? _cleanLabel(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? null : s;
  }

  Widget _hairlineDivider(ThemeData theme) {
    return Divider(
      height: AppShape.gap16,
      thickness: 1,
      color: AppShape.hairline(theme, opacity: 0.25).color,
    );
  }

  void _snack(BuildContext context, String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), duration: const Duration(seconds: 1)),
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailingLabel,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? trailingLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, size: 20, color: theme.colorScheme.primary),
              const SizedBox(width: AppShape.gap10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 20,
                          color: theme.hintColor,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.hintColor,
                      ),
                    ),
                    if (trailingLabel != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        trailingLabel!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
