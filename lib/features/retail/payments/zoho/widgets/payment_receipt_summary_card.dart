import 'package:flutter/material.dart';

import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import 'package:afyakit/features/retail/shared/widgets/sales_formatters.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

class PaymentReceiptSummaryCard extends StatelessWidget {
  const PaymentReceiptSummaryCard({
    super.key,
    required this.currencyCode,

    // invoice context
    required this.customerTitle,
    required this.invoiceLabel,
    required this.invoiceDate,
    required this.invoiceTotal,
    required this.invoiceLoading,
    required this.invoiceError,

    // ✅ new: paid + balance (optional)
    this.invoicePaid,
    this.invoiceBalance,

    // selected payment
    required this.paymentId,
    required this.payment,

    // actions
    required this.canManage,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
  });

  final String currencyCode;

  final String customerTitle;
  final String invoiceLabel;
  final DateTime? invoiceDate;
  final num? invoiceTotal;

  final bool invoiceLoading;
  final bool invoiceError;

  final num? invoicePaid;
  final num? invoiceBalance;

  final String paymentId;
  final ZohoInvoicePayment? payment;

  final bool canManage;
  final bool busy;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final invDateText = invoiceDate == null
        ? null
        : 'Invoice date: ${ymd.format(invoiceDate!)}';

    final totalText = invoiceTotal == null
        ? null
        : 'Total: ${money(invoiceTotal!, currencyCode)}';

    final paidText = invoicePaid == null
        ? null
        : 'Paid: ${money(invoicePaid!, currencyCode)}';

    final balanceText = invoiceBalance == null
        ? null
        : 'Balance: ${money(invoiceBalance!, currencyCode)}';

    final showHint = invoiceLoading || invoiceError;
    final hintText = invoiceLoading
        ? 'Loading invoice…'
        : (invoiceError ? 'Invoice info unavailable' : '');

    final p = payment;

    return AppTile(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // ─────────────────────────────
            // Invoice context (top)
            // ─────────────────────────────
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LeadingBox(
                  icon: Icons.receipt_long_outlined,
                  color: scheme.surfaceContainerHighest,
                ),
                const SizedBox(width: AppShape.gap12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        customerTitle.trim().isEmpty
                            ? 'Customer'
                            : customerTitle,
                        style: t.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (showHint && hintText.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          hintText,
                          style: t.bodySmall?.copyWith(
                            color: Theme.of(context).hintColor,
                            fontWeight: FontWeight.w700,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 2),
                      Text(
                        'Invoice: $invoiceLabel',
                        style: t.bodySmall?.copyWith(
                          color: Theme.of(context).hintColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: AppShape.gap12,
                        runSpacing: AppShape.gap6,
                        children: [
                          if (invDateText != null)
                            const _Meta(
                              icon: Icons.event_outlined,
                              text: '',
                            )._withText(invDateText),

                          if (totalText != null)
                            const _Meta(
                              icon: Icons.payments_outlined,
                              text: '',
                            )._withText(totalText),

                          if (paidText != null)
                            _Meta(
                              icon: Icons.check_circle_outline,
                              text: paidText,
                              color: scheme.primary,
                            ),

                          if (balanceText != null)
                            _Meta(
                              icon: Icons.account_balance_wallet_outlined,
                              text: balanceText,
                              color: _balanceColor(scheme, invoiceBalance),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),
            const Divider(height: 1),
            const SizedBox(height: 14),

            // ─────────────────────────────
            // Payment receipt (selected)
            // ─────────────────────────────
            if (p == null)
              Text(
                'Receipt not found.\n\nPayment ID: ${paymentId.trim()}',
                style: t.bodyMedium,
              )
            else
              _PaymentDetails(currencyCode: currencyCode, payment: p),

            if (canManage) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onEdit,
                      icon: const Icon(Icons.edit_outlined),
                      label: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : onDelete,
                      icon: Icon(Icons.delete_outline, color: scheme.error),
                      label: Text(
                        'Delete',
                        style: TextStyle(color: scheme.error),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  static Color? _balanceColor(ColorScheme scheme, num? balance) {
    if (balance == null) return null;
    if (balance > 0) return scheme.error;
    return scheme.primary;
  }
}

class _PaymentDetails extends StatelessWidget {
  const _PaymentDetails({required this.currencyCode, required this.payment});

  final String currencyCode;
  final ZohoInvoicePayment payment;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;

    final pid = payment.paymentId.trim();
    final payDateText = payment.date == null
        ? 'Payment date: —'
        : 'Payment date: ${ymd.format(payment.date!)}';

    final mode = (payment.mode ?? '').trim();
    final ref = (payment.referenceNumber ?? '').trim();
    final desc = (payment.description ?? '').trim();
    final amount = money(payment.amount, currencyCode);

    final showPid = pid.isNotEmpty && pid != ref;

    final bg = scheme.primary.withOpacity(0.06);
    final border = Border.all(color: scheme.primary.withOpacity(0.20));

    // ✅ controlled red label (not “delete” red, but clearly red)
    final receiptLabelColor = scheme.error.withOpacity(0.90);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: border,
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header:
          // - amount truly centered (Stack)
          // - label right-aligned
          // - no magic widths
          SizedBox(
            height: 30,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Center(
                  child: Text(
                    amount,
                    style: t.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: scheme.primary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    'PAYMENT RECEIPT',
                    textAlign: TextAlign.right,
                    style: t.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      letterSpacing: 0.8,
                      color: receiptLabelColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Details: centered distribution
          Align(
            alignment: Alignment.center,
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: AppShape.gap12,
              runSpacing: AppShape.gap6,
              children: [
                _Meta(icon: Icons.event_outlined, text: payDateText),
                if (mode.isNotEmpty)
                  _Meta(
                    icon: Icons.account_balance_outlined,
                    text: 'Method: $mode',
                  ),
                if (ref.isNotEmpty)
                  _Meta(icon: Icons.tag_outlined, text: 'Ref: $ref'),
                if (showPid)
                  _Meta(
                    icon: Icons.receipt_outlined,
                    text: 'ID: ${_shortId(pid, tail: 8)}',
                  ),
              ],
            ),
          ),

          if (desc.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(desc, style: t.bodyMedium),
          ],
        ],
      ),
    );
  }

  static String _shortId(String v, {int tail = 6}) {
    final s = v.trim();
    if (s.isEmpty) return '';
    if (s.length <= tail) return s;
    return '…${s.substring(s.length - tail)}';
  }
}

class _LeadingBox extends StatelessWidget {
  const _LeadingBox({required this.icon, this.color});

  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bg = color ?? scheme.surfaceContainerHighest;

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: bg,
      ),
      child: Icon(icon, size: 20),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta({required this.icon, required this.text, this.color});

  final IconData icon;
  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final c = color ?? Theme.of(context).hintColor;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: c),
        const SizedBox(width: AppShape.gap6),
        Text(
          text,
          style: t.bodySmall?.copyWith(color: c),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

/// Tiny helper to avoid rewriting `_Meta(...)` when you want const + injected text.
/// (keeps build method tidy, still DRY)
extension _MetaX on _Meta {
  _Meta _withText(String text) => _Meta(icon: icon, text: text, color: color);
}
