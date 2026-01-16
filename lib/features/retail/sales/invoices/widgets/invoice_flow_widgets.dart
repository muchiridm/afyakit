import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

final _nf = NumberFormat.decimalPattern();
final _df = DateFormat.yMMMEd();

class ErrorBanner extends StatelessWidget {
  const ErrorBanner(this.message, {super.key});
  final String? message;

  @override
  Widget build(BuildContext context) {
    final msg = (message ?? '').trim();
    if (msg.isEmpty) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Text(msg, style: TextStyle(color: theme.colorScheme.error)),
    );
  }
}

class InvoiceTopBar extends StatelessWidget {
  const InvoiceTopBar({
    super.key,
    required this.title,
    required this.date,
    required this.onPickDate,
    this.subtitle,
    this.trailing,
    this.error,
  });

  final String title;
  final String? subtitle;

  final DateTime? date;

  final VoidCallback onPickDate;
  final Widget? trailing;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final t = theme.textTheme;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final d = date ?? today;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: t.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if ((subtitle ?? '').trim().isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: t.bodySmall?.copyWith(
                          color: t.bodySmall?.color?.withOpacity(0.75),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              _pill(
                context,
                Icons.event_outlined,
                _df.format(d),
                onTap: onPickDate,
              ),
            ],
          ),
          if ((error ?? '').trim().isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(error!, style: TextStyle(color: theme.colorScheme.error)),
          ],
        ],
      ),
    );
  }

  Widget _pill(
    BuildContext context,
    IconData icon,
    String text, {
    VoidCallback? onTap,
  }) {
    final chip = Chip(
      visualDensity: VisualDensity.compact,
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [Icon(icon, size: 16), const SizedBox(width: 6), Text(text)],
      ),
    );

    if (onTap == null) return chip;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: chip,
    );
  }
}

class InvoiceTotalBar extends StatelessWidget {
  const InvoiceTotalBar({
    super.key,
    required this.label,
    required this.amount,
    this.currencyCode = '',
  });

  final String label;
  final num amount;
  final String currencyCode;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final code = currencyCode.trim();
    final money = '${code.isEmpty ? '' : '$code '}${_nf.format(amount)}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
          Text(
            money,
            style: t.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
