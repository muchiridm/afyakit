// lib/features/retail/payments/widgets/payment_detail_screen.dart

import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/providers/payment_providers.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_editor_sheet.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_receipt_summary_card.dart';
import 'package:afyakit/features/retail/shared/sales_doc/feedback.dart';
import 'package:afyakit/shared/layout/app_page.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
  ConsumerState<PaymentDetailScreen> createState() {
    return _PaymentDetailScreenState();
  }
}

class _PaymentDetailScreenState extends ConsumerState<PaymentDetailScreen> {
  static const double _maxW = 720;

  String get _invoiceId => widget.invoiceId.trim();

  String get _paymentId => widget.paymentId.trim();

  @override
  Widget build(BuildContext context) {
    final String invoiceId = _invoiceId;
    final String paymentId = _paymentId;

    if (invoiceId.isEmpty || paymentId.isEmpty) {
      return AppPage(
        title: 'Receipt',
        showBack: true,
        maxWidth: _maxW,
        scrollable: true,
        body: const Padding(
          padding: EdgeInsets.all(16),
          child: InlineErrorCard(message: 'Missing invoice or payment id.'),
        ),
      );
    }

    final provider = paymentControllerProvider(invoiceId);

    final PaymentState paymentState = ref.watch(provider);
    final PaymentController paymentCtl = ref.read(provider.notifier);

    final vmAsync = ref.watch(
      paymentReceiptVmProvider((invoiceId: invoiceId, paymentId: paymentId)),
    );

    return AppPage(
      title: 'Receipt',
      showBack: true,
      maxWidth: _maxW,
      scrollable: true,
      actions: _buildActions(
        state: paymentState,
        ctl: paymentCtl,
        invoiceId: invoiceId,
        paymentId: paymentId,
      ),
      body: vmAsync.when(
        loading: _buildLoading,
        error: (Object error, StackTrace _) => _buildError(error),
        data: (PaymentReceiptVm vm) {
          return _buildReceiptContent(
            context: context,
            paymentState: paymentState,
            paymentCtl: paymentCtl,
            vm: vm,
          );
        },
      ),
    );
  }

  List<Widget> _buildActions({
    required PaymentState state,
    required PaymentController ctl,
    required String invoiceId,
    required String paymentId,
  }) {
    final bool busy = state.busy;

    return <Widget>[
      IconButton(
        tooltip: 'Refresh',
        onPressed: busy
            ? null
            : () async {
                await ctl.refresh();

                _invalidateReceipt(invoiceId: invoiceId, paymentId: paymentId);
              },
        icon: const Icon(Icons.refresh),
      ),
      if (widget.canManagePayments)
        FilledButton.icon(
          onPressed: busy
              ? null
              : () async {
                  ctl.startNewPayment();

                  await PaymentEditorSheet.open(context, invoiceId: invoiceId);

                  _invalidateReceipt(
                    invoiceId: invoiceId,
                    paymentId: paymentId,
                  );
                },
          icon: const Icon(Icons.add),
          label: const Text('Record'),
        ),
    ];
  }

  Widget _buildReceiptContent({
    required BuildContext context,
    required PaymentState paymentState,
    required PaymentController paymentCtl,
    required PaymentReceiptVm vm,
  }) {
    final inv = vm.invoice;
    final contact = vm.contact;
    final ZohoInvoicePayment payment = vm.payment;

    final bool busy = paymentState.busy;
    final bool canManage = widget.canManagePayments;
    final String code = _currency(widget.currencyCode);

    final String customerTitle = _pickFirstNonEmpty(
      contact?.title,
      inv.customerName,
      widget.customerName,
      'Customer',
    );

    final String invoiceLabel = _pickFirstNonEmpty(
      inv.invoiceNumber,
      widget.invoiceNumber,
      widget.invoiceId,
      '-',
    );

    final DateTime? invoiceDate = inv.date ?? widget.invoiceDate;
    final num? invoiceTotal = inv.total != 0 ? inv.total : widget.invoiceTotal;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
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
            paymentId: _paymentId,
            payment: payment,
            canManage: canManage,
            busy: busy,
            onEdit: !canManage || busy
                ? null
                : () async {
                    paymentCtl.startEditPayment(payment);

                    await PaymentEditorSheet.open(
                      context,
                      invoiceId: _invoiceId,
                    );

                    _invalidateReceipt(
                      invoiceId: _invoiceId,
                      paymentId: _paymentId,
                    );
                  },
            onDelete: !canManage || busy
                ? null
                : () => _confirmAndDelete(
                    context: context,
                    ctl: paymentCtl,
                    payment: payment,
                  ),
          ),
        ),

        const SizedBox(height: 24),
      ],
    );
  }

  Future<void> _confirmAndDelete({
    required BuildContext context,
    required PaymentController ctl,
    required ZohoInvoicePayment payment,
  }) async {
    final String paymentId = payment.paymentId.trim();

    if (paymentId.isEmpty) return;

    final bool ok = await DialogService.confirm(
      context: context,
      title: 'Delete receipt?',
      content: 'This will delete the payment in Zoho Books.',
      confirmText: 'Delete',
      confirmColor: Colors.redAccent,
      barrierDismissible: false,
    );

    if (!ok) return;

    final bool deleted = await ctl.deletePayment(paymentId);

    if (!deleted) return;

    _invalidateInvoicePaymentData(_invoiceId);

    ref.invalidate(
      paymentReceiptVmProvider((invoiceId: _invoiceId, paymentId: paymentId)),
    );

    if (!context.mounted) return;

    Navigator.of(context).maybePop();
  }

  void _invalidateReceipt({
    required String invoiceId,
    required String paymentId,
  }) {
    _invalidateInvoicePaymentData(invoiceId);

    final String payId = paymentId.trim();

    if (payId.isEmpty) return;

    ref.invalidate(
      paymentReceiptVmProvider((invoiceId: invoiceId.trim(), paymentId: payId)),
    );
  }

  void _invalidateInvoicePaymentData(String invoiceId) {
    final String id = invoiceId.trim();

    if (id.isEmpty) return;

    ref.invalidate(invoicePaymentsProvider(id));
    ref.invalidate(invoiceProvider(id));
    ref.invalidate(invoiceContactProvider(id));
  }

  String _currency(String value) {
    final String text = value.trim();
    return text.isEmpty ? 'KES' : text;
  }

  Widget _buildLoading() {
    return const Center(
      child: Padding(
        padding: EdgeInsets.only(top: 24),
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildError(Object error) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: InlineErrorCard(message: 'Failed to load receipt.\n$error'),
    );
  }

  static String _pickFirstNonEmpty(
    String? a,
    String? b,
    String? c,
    String? fallback,
  ) {
    for (final String? value in <String?>[a, b, c, fallback]) {
      final String text = (value ?? '').trim();

      if (text.isNotEmpty) return text;
    }

    return '';
  }
}
