// lib/features/retail/payments/widgets/payment_history_section.dart

import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/shared/sales_doc/helpers.dart';
import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';
import 'package:flutter/material.dart';

typedef PaymentTap = void Function(ZohoInvoicePayment payment);
typedef PaymentAction = Future<void> Function(ZohoInvoicePayment payment);

class PaymentHistorySection extends StatelessWidget {
  const PaymentHistorySection({
    super.key,
    required this.currencyCode,
    required this.payments,
    required this.loading,
    required this.busy,
    required this.canManage,
    required this.onRefresh,
    this.error,
    this.onRecord,
    this.maxRows,
    this.onOpenReceipt,
    this.onEdit,
    this.onDelete,
    this.excludePaymentId,
    this.title = 'Payments',
    this.leadingIcon = Icons.payments_outlined,
    this.showHeader = true,
    this.showEmptyCard = false,
    this.compact = false,
    this.selectedPaymentId,
  });

  final String currencyCode;
  final List<ZohoInvoicePayment> payments;
  final bool loading;
  final bool busy;
  final bool canManage;
  final String? error;

  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRecord;

  final int? maxRows;
  final PaymentTap? onOpenReceipt;
  final PaymentAction? onEdit;
  final PaymentAction? onDelete;

  final String title;
  final IconData leadingIcon;
  final bool showHeader;
  final bool showEmptyCard;
  final bool compact;
  final String? selectedPaymentId;
  final String? excludePaymentId;

  @override
  Widget build(BuildContext context) {
    final String err = (error ?? '').trim();

    if (loading) {
      return const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (err.isNotEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text('Failed to load payments.\n$err'),
      );
    }

    final List<ZohoInvoicePayment> rows = _prepareRows();
    final List<ZohoInvoicePayment> visible = _takeMax(rows);

    if (rows.isEmpty && showEmptyCard) {
      return AppTile(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Text(
            'No payments recorded.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        if (showHeader) ...<Widget>[
          _HeaderRow(
            title: title,
            leadingIcon: leadingIcon,
            canManage: canManage,
            busy: busy,
            onRefresh: onRefresh,
            onRecord: onRecord,
          ),
          const SizedBox(height: 10),
        ],
        for (final ZohoInvoicePayment payment in visible) ...<Widget>[
          PaymentHistoryTile(
            currencyCode: _currency(currencyCode),
            payment: payment,
            compact: compact,
            busy: busy,
            canManage: canManage,
            isSelected:
                payment.paymentId.trim() == (selectedPaymentId ?? '').trim(),
            onTap: onOpenReceipt == null ? null : () => onOpenReceipt!(payment),
            onEdit: onEdit == null ? null : () => onEdit!(payment),
            onDelete: onDelete == null ? null : () => onDelete!(payment),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<ZohoInvoicePayment> _prepareRows() {
    final String exclude = (excludePaymentId ?? '').trim();

    if (exclude.isEmpty) {
      return payments;
    }

    return <ZohoInvoicePayment>[
      for (final ZohoInvoicePayment payment in payments)
        if (payment.paymentId.trim() != exclude) payment,
    ];
  }

  List<ZohoInvoicePayment> _takeMax(List<ZohoInvoicePayment> rows) {
    final int? max = maxRows;

    if (max == null || rows.length <= max) {
      return rows;
    }

    return rows.take(max).toList(growable: false);
  }

  static String _currency(String value) {
    final String text = value.trim();
    return text.isEmpty ? 'KES' : text;
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.title,
    required this.leadingIcon,
    required this.canManage,
    required this.busy,
    required this.onRefresh,
    required this.onRecord,
  });

  final String title;
  final IconData leadingIcon;
  final bool canManage;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        Expanded(
          child: Row(
            children: <Widget>[
              Icon(leadingIcon, size: 18),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          tooltip: 'Refresh',
          onPressed: busy ? null : () => onRefresh(),
          icon: const Icon(Icons.refresh),
        ),
        if (canManage)
          FilledButton.icon(
            onPressed: busy || onRecord == null ? null : () => onRecord!(),
            icon: const Icon(Icons.add),
            label: const Text('Record'),
          ),
      ],
    );
  }
}

class PaymentHistoryTile extends StatelessWidget {
  const PaymentHistoryTile({
    super.key,
    required this.currencyCode,
    required this.payment,
    required this.compact,
    required this.busy,
    required this.canManage,
    required this.isSelected,
    this.onTap,
    this.onEdit,
    this.onDelete,
    this.secondaryText,
  });

  final String currencyCode;
  final ZohoInvoicePayment payment;

  final bool compact;
  final bool busy;
  final bool canManage;
  final bool isSelected;

  final VoidCallback? onTap;
  final Future<void> Function()? onEdit;
  final Future<void> Function()? onDelete;

  final String? secondaryText;

  @override
  Widget build(BuildContext context) {
    final String date = payment.date == null ? '—' : ymd.format(payment.date!);
    final String mode = (payment.mode ?? '').trim().isEmpty
        ? 'Payment'
        : payment.mode!.trim();
    final String amount = money(payment.amount, currencyCode);
    final String subtitle = _subtitle(date);

    final ColorScheme scheme = Theme.of(context).colorScheme;

    final Color background = isSelected
        ? scheme.primary.withOpacity(0.08)
        : scheme.surface;

    final Border border = Border.all(
      color: isSelected
          ? scheme.primary.withOpacity(0.35)
          : scheme.outlineVariant.withOpacity(0.25),
    );

    final EdgeInsets padding = compact
        ? const EdgeInsets.fromLTRB(10, 8, 6, 8)
        : const EdgeInsets.fromLTRB(12, 10, 8, 10);

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: background,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: padding,
          child: Row(
            children: <Widget>[
              const Icon(Icons.receipt_long_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      mode,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        color: isSelected ? scheme.primary : null,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).hintColor,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppShape.gap12),
              Text(amount, style: const TextStyle(fontWeight: FontWeight.w800)),
              if (canManage) ...<Widget>[
                const SizedBox(width: 4),
                PopupMenuButton<_PaymentRowAction>(
                  tooltip: 'More',
                  enabled: !busy,
                  onSelected: (action) async {
                    switch (action) {
                      case _PaymentRowAction.edit:
                        await onEdit?.call();
                        break;
                      case _PaymentRowAction.delete:
                        await onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (_) => <PopupMenuEntry<_PaymentRowAction>>[
                    const PopupMenuItem<_PaymentRowAction>(
                      value: _PaymentRowAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<_PaymentRowAction>(
                      value: _PaymentRowAction.delete,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Theme.of(context).colorScheme.error,
                          ),
                          const SizedBox(width: 10),
                          const Text('Delete'),
                        ],
                      ),
                    ),
                  ],
                  icon: const Icon(Icons.more_vert, size: 20),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  String _subtitle(String date) {
    final String line = (secondaryText ?? '').trim();

    if (line.isNotEmpty) {
      return line;
    }

    final String reference = (payment.reference ?? '').trim();

    if (reference.isNotEmpty) {
      return '$date • $reference';
    }

    return date;
  }
}

enum _PaymentRowAction { edit, delete }
