import 'package:flutter/material.dart';
import 'sales_formatters.dart';

/// Simple single-line total row (quotes, drafts, editors)
class SalesDocTotalBar extends StatelessWidget {
  const SalesDocTotalBar({
    super.key,
    required this.label,
    required this.total,
    required this.currencyCode,
    this.valueColor,
  });

  final String label;
  final num total;
  final String currencyCode;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            money(total, currencyCode),
            style: t.titleMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: valueColor,
            ),
          ),
        ],
      ),
    );
  }
}

/// Multi-row totals stack (invoices: total / paid / balance)
class SalesDocTotalsStack extends StatelessWidget {
  const SalesDocTotalsStack({
    super.key,
    required this.currencyCode,
    required this.total,
    this.paid,
    this.balance,
  });

  final String currencyCode;
  final num total;
  final num? paid;
  final num? balance;

  bool get _isOverdue => balance != null && balance! > 0;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final t = Theme.of(context).textTheme;

    Widget row({required String label, required num value, Color? valueColor}) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: t.labelSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: t.labelSmall?.color?.withOpacity(0.75),
                ),
              ),
            ),
            Text(
              money(value, currencyCode),
              style: t.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: valueColor,
              ),
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
      child: Column(
        children: [
          row(label: 'Total', value: total),
          if (paid != null && paid! > 0)
            row(label: 'Paid', value: paid!, valueColor: cs.primary),
          if (balance != null)
            row(
              label: 'Balance',
              value: balance!,
              valueColor: _isOverdue ? cs.error : cs.onSurface,
            ),
        ],
      ),
    );
  }
}
