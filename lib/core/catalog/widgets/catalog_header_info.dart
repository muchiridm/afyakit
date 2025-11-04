import 'package:flutter/material.dart';

class CatalogHeaderInfo extends StatelessWidget {
  final VoidCallback? onLogin;
  final bool centered; // 👈 new

  const CatalogHeaderInfo({super.key, this.onLogin, this.centered = false});

  @override
  Widget build(BuildContext context) {
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
        Wrap(
          spacing: 16,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          alignment: centered
              ? WrapAlignment.center
              : WrapAlignment.end, // 👈 key
          children: [
            _InfoItem(
              icon: Icons.chat_bubble_outline,
              label: 'WhatsApp',
              value: '+254 718 182 074',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _InfoItem(
              icon: Icons.payments_rounded,
              label: 'M-Pesa Till',
              value: '5687330',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
            _InfoItem(
              icon: Icons.verified_rounded,
              label: 'Reg. No.',
              value: 'PPB/D/3483',
              labelStyle: labelStyle,
              valueStyle: valueStyle,
            ),
          ],
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16),
        const SizedBox(width: 6),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: labelStyle),
            Text(value, style: valueStyle),
          ],
        ),
      ],
    );
  }
}
