// lib/features/retail/sales/payments/widgets/payment_detail_screen.dart

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_state.dart';
import 'package:afyakit/features/retail/payments/zoho/providers/payment_receipt_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';

import 'package:afyakit/features/retail/payments/zoho/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payment_editor_sheet.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payment_receipt_summary_card.dart';
import 'package:afyakit/features/retail/payments/zoho/widgets/payment_history_section.dart';
import 'package:afyakit/features/retail/shared/models/zoho_invoice_payment.dart';

class PaymentDetailScreen extends ConsumerStatefulWidget {
  const PaymentDetailScreen({
    super.key,
    required this.invoiceId,
    required this.paymentId,
    this.currencyCode = 'KES',
    this.customerName,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceTotal,
    this.canManagePayments = true,
  });

  final String invoiceId;
  final String paymentId;
  final String currencyCode;

  final String? customerName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final num? invoiceTotal;

  final bool canManagePayments;

  @override
  ConsumerState<PaymentDetailScreen> createState() =>
      _PaymentDetailScreenState();
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  static const double _maxW = 720;

  @override
  Widget build(BuildContext context) {
    final invId = widget.invoiceId.trim();
    final payId = widget.paymentId.trim();

    final paymentState = ref.watch(paymentControllerProvider(invId));
    final paymentCtl = ref.read(paymentControllerProvider(invId).notifier);

    final vmAsync = ref.watch(
      paymentReceiptVmProvider((invoiceId: invId, paymentId: payId)),
    );

    return AppPage(
      title: 'Receipt',
      showBack: true,
      maxWidth: _maxW,
      scrollable: true,
      actions: _buildActions(paymentState, paymentCtl, invId),
      body: vmAsync.when(
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(e),
        data: (vm) => _buildReceiptContent(
          context: context,
          paymentState: paymentState,
          paymentCtl: paymentCtl,
          vm: vm,
        ),
      ),
    );
  }

  // ─────────────────────────────
  // Actions
  // ─────────────────────────────

  List<Widget> _buildActions(
    PaymentState state,
    PaymentController ctl,
    String invoiceId,
  ) {
    final busy = state.busy;

    return [
      IconButton(
        tooltip: 'Refresh',
        onPressed: busy
            ? null
            : () async {
                // refresh mutation-state (optional)
                await ctl.refresh();
                // refresh invoice-scoped providers (this is the REAL data source now)
                ref.invalidate(invoicePaymentsProvider(invoiceId));
                ref.invalidate(invoiceProvider(invoiceId));
                ref.invalidate(invoiceContactProvider(invoiceId));
              },
        icon: const Icon(Icons.refresh),
      ),
      if (widget.canManagePayments)
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  ctl.startNewPayment();
                  await PaymentEditorSheet.open(
                    context,
                    invoiceId: widget.invoiceId,
                  );
                  // after recording, ensure history updates
                  ref.invalidate(invoicePaymentsProvider(invoiceId.trim()));
                },
          icon: const Icon(Icons.add),
          label: const Text('Record'),
        ),
    ];
  }

  // ─────────────────────────────
  // Receipt content
  // ─────────────────────────────

  Widget _buildReceiptContent({
    required BuildContext context,
    required PaymentState paymentState,
    required PaymentController paymentCtl,
    required PaymentReceiptVm vm,
  }) {
    final inv = vm.invoice;
    final contact = vm.contact;
    final ZohoInvoicePayment payment = vm.payment;

    final busy = paymentState.busy;
    final canManage = widget.canManagePayments;
    final code = _currency(widget.currencyCode);

    final customerTitle = _pickFirstNonEmpty(
      contact?.title,
      inv.customerName,
      widget.customerName,
      'Customer',
    );

    final invoiceLabel = _pickFirstNonEmpty(
      inv.invoiceNumber,
      widget.invoiceNumber,
      widget.invoiceId,
      '-',
    );

    final invoiceDate = inv.date ?? widget.invoiceDate;
    final invoiceTotal = inv.total != 0 ? inv.total : widget.invoiceTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (busy) const LinearProgressIndicator(minHeight: 2),
        InlineErrorCard(message: (paymentState.error ?? '').trim()),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: PaymentReceiptSummaryCard(
            currencyCode: code,
            customerTitle: customerTitle,
            invoiceLabel: invoiceLabel,
            invoiceDate: invoiceDate,
            invoiceTotal: invoiceTotal,
            invoiceLoading: false,
            invoiceError: false,
            paymentId: widget.paymentId,
            payment: payment,
            canManage: canManage,
            busy: busy,
            onEdit: (!canManage || busy)
                ? null
                : () async {
                    paymentCtl.startEditPayment(payment);
                    await PaymentEditorSheet.open(
                      context,
                      invoiceId: widget.invoiceId,
                    );
                    ref.invalidate(
                      invoicePaymentsProvider(widget.invoiceId.trim()),
                    );
                  },
            onDelete: (!canManage || busy)
                ? null
                : () => _confirmAndDelete(context, paymentCtl, payment),
          ),
        ),
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: PaymentHistorySection(
            title: 'Other payments on this invoice',
            leadingIcon: Icons.history,
            currencyCode: code,
            invoiceId: widget.invoiceId,
            excludePaymentId: widget.paymentId,
            onRefresh: () async {
              await paymentCtl.refresh();
              ref.invalidate(invoicePaymentsProvider(widget.invoiceId.trim()));
            },
            canManage: canManage,
            maxRows: 8,
            compact: true,
            showHeader: true,
            showEmptyCard: true,
            selectedPaymentId: widget.paymentId,
            onOpenReceipt: (p) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => PaymentDetailScreen(
                    invoiceId: widget.invoiceId,
                    paymentId: p.paymentId,
                    currencyCode: code,
                    customerName: widget.customerName,
                    invoiceNumber: widget.invoiceNumber,
                    invoiceDate: widget.invoiceDate,
                    invoiceTotal: widget.invoiceTotal,
                    canManagePayments: canManage,
                  ),
                ),
              );
            },
            onEdit: canManage && !busy
                ? (p) async {
                    paymentCtl.startEditPayment(p);
                    await PaymentEditorSheet.open(
                      context,
                      invoiceId: widget.invoiceId,
                    );
                    ref.invalidate(
                      invoicePaymentsProvider(widget.invoiceId.trim()),
                    );
                  }
                : null,
            onDelete: canManage && !busy
                ? (p) => _confirmAndDelete(context, paymentCtl, p)
                : null,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // ─────────────────────────────
  // Small helpers
  // ─────────────────────────────

  String _currency(String s) => s.trim().isEmpty ? 'KES' : s.trim();

  Widget _buildLoading() => const Center(
    child: Padding(
      padding: EdgeInsets.only(top: 24),
      child: CircularProgressIndicator(),
    ),
  );

  Widget _buildError(Object e) => Padding(
    padding: const EdgeInsets.all(16),
    child: Text('Failed to load receipt.\n$e'),
  );

  Future<void> _confirmAndDelete(
    BuildContext context,
    PaymentController ctl,
    ZohoInvoicePayment p,
  ) async {
    final ok = await DialogService.confirm(
      context: context,
      title: 'Delete receipt?',
      content: 'This will delete the payment in Zoho Books.',
      confirmText: 'Delete',
      confirmColor: Colors.redAccent,
      barrierDismissible: false,
    );
    if (!ok) return;

    await ctl.deletePayment(p.paymentId);

    // Ensure lists refresh after deletion.
    ref.invalidate(invoicePaymentsProvider(widget.invoiceId.trim()));

    if (!context.mounted) return;
    Navigator.of(context).maybePop();
  }

  static String _pickFirstNonEmpty(
    String? a,
    String? b,
    String? c,
    String? fallback,
  ) {
    for (final v in [a, b, c, fallback]) {
      final t = (v ?? '').trim();
      if (t.isNotEmpty) return t;
    }
    return '';
  }
}
