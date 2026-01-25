import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payment_detail_screen.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payment_editor_sheet.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

import 'package:afyakit/shared/services/dialog_service.dart';

import 'package:afyakit/features/retail/payments/zoho/widgets/payment_history_section.dart';

class PaymentFooter extends ConsumerWidget {
  const PaymentFooter({
    super.key,
    required this.currencyCode,
    required this.invoiceId,
    required this.canManageInvoices,

    // Invoice context (optional)
    this.customerName,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceTotal,
  });

  final String currencyCode;
  final String invoiceId;
  final bool canManageInvoices;

  final String? customerName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final num? invoiceTotal;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(paymentControllerProvider(invoiceId));
    final ctl = ref.read(paymentControllerProvider(invoiceId).notifier);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: PaymentHistorySection(
            currencyCode: currencyCode,
            invoiceId: invoiceId,

            // Provider-driven section will load + scope payments itself.
            onRefresh: ctl.refresh,

            canManage: canManageInvoices,
            onRecord: (!canManageInvoices || s.busy)
                ? null
                : () async {
                    ctl.startNewPayment();
                    await PaymentEditorSheet.open(
                      context,
                      invoiceId: invoiceId,
                    );
                  },

            maxRows: 4,

            onOpenReceipt: (p) => _openReceipt(context, p),

            onEdit: canManageInvoices && !s.busy
                ? (p) async {
                    ctl.startEditPayment(p);
                    await PaymentEditorSheet.open(
                      context,
                      invoiceId: invoiceId,
                    );
                  }
                : null,

            onDelete: canManageInvoices && !s.busy
                ? (p) => _confirmAndDelete(context, ctl, p)
                : null,
          ),
        ),
      ],
    );
  }

  void _openReceipt(BuildContext context, ZohoInvoicePayment p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          invoiceId: invoiceId,
          currencyCode: currencyCode,

          // optional context
          customerName: customerName,
          invoiceNumber: invoiceNumber,
          invoiceDate: invoiceDate,
          invoiceTotal: invoiceTotal,

          canManagePayments: canManageInvoices,
          paymentId: p.paymentId,
        ),
      ),
    );
  }

  Future<void> _confirmAndDelete(
    BuildContext context,
    PaymentController ctl,
    ZohoInvoicePayment p,
  ) async {
    final ok = await DialogService.confirm(
      context: context,
      title: 'Delete payment?',
      content: 'This will remove the payment in Zoho Books.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      confirmColor: Colors.redAccent,
      barrierDismissible: false,
    );
    if (!ok) return;

    await ctl.deletePayment(p.paymentId);
  }
}
