// lib/features/retail/sales/payments/widgets/payment_history_section.dart

import 'package:afyakit/features/retail/shared/providers/payment_receipt_providers.dart';
import 'package:afyakit/features/retail/shared/sales_doc/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/theme/app_shape.dart';
import 'package:afyakit/shared/widgets/app_tile.dart';

import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

typedef PaymentTap = void Function(ZohoInvoicePayment p);

class PaymentHistorySection extends ConsumerWidget {
  const PaymentHistorySection({
    super.key,
    required this.currencyCode,
    required this.invoiceId,
    required this.onRefresh,
    required this.canManage,
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
  final String invoiceId;

  final Future<void> Function() onRefresh;
  final bool canManage;
  final Future<void> Function()? onRecord;

  final int? maxRows;
  final PaymentTap? onOpenReceipt;
  final Future<void> Function(ZohoInvoicePayment p)? onEdit;
  final Future<void> Function(ZohoInvoicePayment p)? onDelete;

  final String title;
  final IconData leadingIcon;
  final bool showHeader;
  final bool showEmptyCard;
  final bool compact;
  final String? selectedPaymentId;

  /// Exclude one payment (used by receipt screen)
  final String? excludePaymentId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final code = _currency(currencyCode);
    final invId = invoiceId.trim();

    final asyncPays = ref.watch(invoicePaymentsProvider(invId));

    return asyncPays.when(
      loading: () => _buildLoading(),
      error: (e, _) => _buildError(e),
      data: (pays) => _buildData(context: context, code: code, pays: pays),
    );
  }

  // ─────────────────────────────
  // Private builders
  // ─────────────────────────────

  String _currency(String s) => s.trim().isEmpty ? 'KES' : s.trim();

  Widget _buildLoading() => const Padding(
    padding: EdgeInsets.all(16),
    child: Center(child: CircularProgressIndicator()),
  );

  Widget _buildError(Object e) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text('Failed to load payments.\n$e'),
  );

  Widget _buildEmptyCard(BuildContext context) => AppTile(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Text(
        'No payments recorded.',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    ),
  );

  Widget _buildData({
    required BuildContext context,
    required String code,
    required List<ZohoInvoicePayment> pays,
  }) {
    final rows = _prepareRows(pays);
    final visible = _takeMax(rows, maxRows);

    if (rows.isEmpty && showEmptyCard) {
      return _buildEmptyCard(context);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (showHeader) ...[
          _HeaderRow(
            title: title,
            leadingIcon: leadingIcon,
            canManage: canManage,
            onRefresh: onRefresh,
            onRecord: onRecord,
          ),
          const SizedBox(height: 10),
        ],
        for (final p in visible) ...[
          PaymentHistoryTile(
            currencyCode: code,
            p: p,
            compact: compact,
            busy: false,
            canManage: canManage,
            isSelected: p.paymentId.trim() == (selectedPaymentId ?? '').trim(),
            onTap: onOpenReceipt == null ? null : () => onOpenReceipt!(p),
            onEdit: onEdit == null ? null : () => onEdit!(p),
            onDelete: onDelete == null ? null : () => onDelete!(p),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  List<ZohoInvoicePayment> _prepareRows(List<ZohoInvoicePayment> pays) {
    final exclude = (excludePaymentId ?? '').trim();
    if (exclude.isEmpty) return pays;
    return <ZohoInvoicePayment>[
      for (final p in pays)
        if (p.paymentId.trim() != exclude) p,
    ];
  }

  List<ZohoInvoicePayment> _takeMax(List<ZohoInvoicePayment> xs, int? maxRows) {
    if (maxRows == null || xs.length <= maxRows) return xs;
    return xs.take(maxRows).toList();
  }
}

class _HeaderRow extends StatelessWidget {
  const _HeaderRow({
    required this.title,
    required this.leadingIcon,
    required this.canManage,
    required this.onRefresh,
    required this.onRecord,
  });

  final String title;
  final IconData leadingIcon;
  final bool canManage;
  final Future<void> Function() onRefresh;
  final Future<void> Function()? onRecord;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Row(
            children: [
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
          onPressed: () => onRefresh(),
          icon: const Icon(Icons.refresh),
        ),
        if (canManage)
          FilledButton.icon(
            onPressed: onRecord == null ? null : () => onRecord?.call(),
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
    required this.p,
    required this.compact,
    required this.busy,
    required this.canManage,
    required this.isSelected,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
    this.secondaryText,
  });

  final String currencyCode;
  final ZohoInvoicePayment p;

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
    final date = p.date == null ? '—' : ymd.format(p.date!);
    final mode = (p.mode ?? '').trim().isEmpty ? 'Payment' : p.mode!.trim();
    final ref = (p.referenceNumber ?? '').trim();
    final amount = money(p.amount, currencyCode);

    final scheme = Theme.of(context).colorScheme;

    final bg = isSelected ? scheme.primary.withOpacity(0.08) : scheme.surface;
    final border = Border.all(
      color: isSelected
          ? scheme.primary.withOpacity(0.35)
          : scheme.outlineVariant.withOpacity(0.25),
    );

    final pad = compact
        ? const EdgeInsets.fromLTRB(10, 8, 6, 8)
        : const EdgeInsets.fromLTRB(12, 10, 8, 10);

    final line2 = (secondaryText ?? '').trim();
    final fallback2 = ref.isEmpty ? date : '$date • $ref';
    final subtitle = line2.isNotEmpty ? line2 : fallback2;

    return Material(
      borderRadius: BorderRadius.circular(12),
      color: bg,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            border: border,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: pad,
          child: Row(
            children: [
              const Icon(Icons.receipt_long_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
              if (canManage) ...[
                const SizedBox(width: 4),
                PopupMenuButton<_PayRowAction>(
                  tooltip: 'More',
                  enabled: !busy,
                  onSelected: (a) async {
                    switch (a) {
                      case _PayRowAction.edit:
                        await onEdit?.call();
                        break;
                      case _PayRowAction.delete:
                        await onDelete?.call();
                        break;
                    }
                  },
                  itemBuilder: (_) => [
                    const PopupMenuItem<_PayRowAction>(
                      value: _PayRowAction.edit,
                      child: Text('Edit'),
                    ),
                    PopupMenuItem<_PayRowAction>(
                      value: _PayRowAction.delete,
                      child: Row(
                        children: [
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
}

enum _PayRowAction { edit, delete }
