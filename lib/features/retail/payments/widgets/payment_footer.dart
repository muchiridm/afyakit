// lib/features/retail/payments/widgets/payment_footer.dart

import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_detail_screen.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_editor_sheet.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_history_section.dart';
import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class PaymentFooter extends ConsumerWidget {
  const PaymentFooter({
    super.key,
    required this.currencyCode,
    required this.invoiceId,
    required this.canManageInvoices,
    this.customerName,
    this.invoiceNumber,
    this.invoiceDate,
    this.invoiceTotal,
    this.pendingAmount,
    this.suggestedPhone,
    this.onPaymentSuccess,
  });

  final String currencyCode;
  final String invoiceId;
  final bool canManageInvoices;

  final String? customerName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final num? invoiceTotal;

  final num? pendingAmount;
  final String? suggestedPhone;

  final Future<void> Function()? onPaymentSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final String invId = invoiceId.trim();

    if (invId.isEmpty) {
      return const SizedBox.shrink();
    }

    final PaymentState state = ref.watch(paymentControllerProvider(invId));
    final PaymentController controller = ref.read(
      paymentControllerProvider(invId).notifier,
    );

    final num? pending =
        _validPending(state.pendingAmount) ?? _validPending(pendingAmount);

    final String? phoneHint =
        _clean(state.suggestedMpesaPhone) ?? _clean(suggestedPhone);

    final bool busy = state.busy;
    final bool hasBalance = pending != null && pending > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        const Divider(height: 1),
        if (hasBalance)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: _MpesaPromptPayCard(
              currencyCode: _currency(currencyCode),
              pendingAmount: pending,
              phoneHint: phoneHint,
              busy: busy,
              payingMpesa: state.payingMpesa,
              mpesaStatusText: _mpesaStatusText(state.mpesaLastPayment),
              onPay: busy
                  ? null
                  : (String phone, num amount) {
                      return _handleMpesaPay(
                        controller: controller,
                        phone: phone,
                        amount: amount,
                        pending: pending,
                        phoneHint: phoneHint,
                      );
                    },
            ),
          ),
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: PaymentHistorySection(
            currencyCode: _currency(currencyCode),
            payments: state.payments,
            loading: state.loadingPayments,
            busy: busy,
            error: state.error,
            canManage: canManageInvoices,
            onRefresh: controller.refresh,
            onRecord: !canManageInvoices || busy
                ? null
                : () => _handleRecord(
                    context: context,
                    controller: controller,
                    invoiceId: invId,
                  ),
            maxRows: 4,
            onOpenReceipt: (ZohoInvoicePayment payment) {
              _openReceipt(context, payment);
            },
            onEdit: canManageInvoices && !busy
                ? (ZohoInvoicePayment payment) => _handleEdit(
                    context: context,
                    controller: controller,
                    invoiceId: invId,
                    payment: payment,
                  )
                : null,
            onDelete: canManageInvoices && !busy
                ? (ZohoInvoicePayment payment) => _handleDelete(
                    context: context,
                    controller: controller,
                    payment: payment,
                  )
                : null,
          ),
        ),
      ],
    );
  }

  Future<void> _handleMpesaPay({
    required PaymentController controller,
    required String phone,
    required num amount,
    required num? pending,
    required String? phoneHint,
  }) async {
    controller.seedFromInvoiceContext(
      pendingAmount: pending,
      suggestedPhone: phoneHint,
    );

    final bool ok = await controller.payViaMpesaStk(
      phone: phone,
      amount: amount,
    );

    if (!ok) return;

    await onPaymentSuccess?.call();
  }

  Future<void> _handleRecord({
    required BuildContext context,
    required PaymentController controller,
    required String invoiceId,
  }) async {
    controller.startNewPayment();

    controller.seedFromInvoiceContext(
      pendingAmount: pendingAmount,
      suggestedPhone: suggestedPhone,
    );

    await PaymentEditorSheet.open(context, invoiceId: invoiceId);

    await onPaymentSuccess?.call();
  }

  Future<void> _handleEdit({
    required BuildContext context,
    required PaymentController controller,
    required String invoiceId,
    required ZohoInvoicePayment payment,
  }) async {
    controller.startEditPayment(payment);

    controller.seedFromInvoiceContext(
      pendingAmount: pendingAmount,
      suggestedPhone: suggestedPhone,
    );

    await PaymentEditorSheet.open(context, invoiceId: invoiceId);

    await onPaymentSuccess?.call();
  }

  Future<void> _handleDelete({
    required BuildContext context,
    required PaymentController controller,
    required ZohoInvoicePayment payment,
  }) async {
    final bool ok = await DialogService.confirm(
      context: context,
      title: 'Delete payment?',
      content: 'This will remove the payment in Zoho Books.',
      cancelText: 'Cancel',
      confirmText: 'Delete',
      confirmColor: Colors.redAccent,
      barrierDismissible: false,
    );

    if (!ok) return;

    final bool deleted = await controller.deletePayment(payment.paymentId);

    if (!deleted) return;

    await onPaymentSuccess?.call();
  }

  void _openReceipt(BuildContext context, ZohoInvoicePayment payment) {
    final String paymentId = payment.paymentId.trim();

    if (paymentId.isEmpty) return;

    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PaymentDetailScreen(
          invoiceId: invoiceId,
          paymentId: paymentId,
          currencyCode: _currency(currencyCode),
          customerName: customerName,
          invoiceNumber: invoiceNumber,
          invoiceDate: invoiceDate,
          invoiceTotal: invoiceTotal,
          canManagePayments: canManageInvoices,
        ),
      ),
    );
  }

  static num? _validPending(num? value) {
    if (value == null) return null;
    if (!value.isFinite) return null;
    if (value <= 0) return null;

    return value;
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();

    return text.isEmpty ? null : text;
  }

  static String _currency(String value) {
    final String text = value.trim();

    return text.isEmpty ? 'KES' : text;
  }

  static String? _mpesaStatusText(Object? last) {
    if (last == null) return null;

    try {
      final dynamic payment = last;

      final String status = (payment.status ?? '').toString().trim();
      final String code = (payment.resultCode ?? '').toString().trim();
      final String desc = (payment.resultDesc ?? '').toString().trim();

      final List<String> parts = <String>[];

      if (status.isNotEmpty) parts.add(status);
      if (code.isNotEmpty) parts.add('($code)');
      if (desc.isNotEmpty) parts.add(desc);

      final String text = parts.join(' ');

      return text.isEmpty ? null : text;
    } catch (_) {
      return null;
    }
  }
}

typedef _MpesaPayFn = Future<void> Function(String phone, num amount);

class _MpesaPromptPayCard extends StatefulWidget {
  const _MpesaPromptPayCard({
    required this.currencyCode,
    required this.pendingAmount,
    required this.phoneHint,
    required this.busy,
    required this.payingMpesa,
    required this.mpesaStatusText,
    required this.onPay,
  });

  final String currencyCode;
  final num pendingAmount;
  final String? phoneHint;
  final bool busy;
  final bool payingMpesa;
  final String? mpesaStatusText;
  final _MpesaPayFn? onPay;

  @override
  State<_MpesaPromptPayCard> createState() {
    return _MpesaPromptPayCardState();
  }
}

class _MpesaPromptPayCardState extends State<_MpesaPromptPayCard> {
  late final TextEditingController _phoneCtl;
  late final TextEditingController _amountCtl;

  @override
  void initState() {
    super.initState();

    _phoneCtl = TextEditingController(text: widget.phoneHint ?? '');
    _amountCtl = TextEditingController(
      text: _formatAmount(widget.pendingAmount),
    );
  }

  @override
  void didUpdateWidget(covariant _MpesaPromptPayCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    _seedPhoneIfEmpty();
    _seedAmountIfStillOldPending(oldWidget.pendingAmount);
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bool canPay =
        widget.onPay != null &&
        !widget.busy &&
        !widget.payingMpesa &&
        widget.pendingAmount > 0;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            _Header(
              currencyCode: widget.currencyCode,
              pendingAmount: widget.pendingAmount,
              payingMpesa: widget.payingMpesa,
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _phoneCtl,
              keyboardType: TextInputType.phone,
              enabled: !widget.busy && !widget.payingMpesa,
              decoration: const InputDecoration(
                labelText: 'Phone (M-Pesa)',
                hintText: '07XXXXXXXX / 01XXXXXXXX / 2547XXXXXXXX',
                prefixIcon: Icon(Icons.call_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _amountCtl,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              enabled: !widget.busy && !widget.payingMpesa,
              decoration: InputDecoration(
                labelText: 'Amount',
                hintText: _formatAmount(widget.pendingAmount),
                prefixIcon: const Icon(Icons.payments_outlined),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if ((widget.mpesaStatusText ?? '').trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                widget.mpesaStatusText!.trim(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: canPay ? () => _submit(context) : null,
              icon: const Icon(Icons.payments_outlined),
              label: Text(widget.payingMpesa ? 'Prompting…' : 'Prompt & Pay'),
            ),
            const SizedBox(height: 6),
            Text(
              'You’ll receive an M-Pesa prompt on your phone. Complete it to pay this invoice.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submit(BuildContext context) async {
    final String phone = _phoneCtl.text.trim();

    if (phone.isEmpty) {
      _showSnack(context, 'Enter your M-Pesa phone number');
      return;
    }

    final num? amount = num.tryParse(_amountCtl.text.trim());

    if (amount == null || amount <= 0) {
      _showSnack(context, 'Enter a valid amount');
      return;
    }

    if (amount > widget.pendingAmount) {
      _showSnack(
        context,
        'Amount cannot exceed balance (${_formatAmount(widget.pendingAmount)})',
      );
      return;
    }

    await widget.onPay?.call(phone, amount);
  }

  void _seedPhoneIfEmpty() {
    final String current = _phoneCtl.text.trim();
    final String next = (widget.phoneHint ?? '').trim();

    if (current.isEmpty && next.isNotEmpty) {
      _phoneCtl.text = next;
    }
  }

  void _seedAmountIfStillOldPending(num oldPending) {
    final String current = _amountCtl.text.trim();
    final String oldText = _formatAmount(oldPending);
    final String nextText = _formatAmount(widget.pendingAmount);

    if (current == oldText && current != nextText) {
      _amountCtl.text = nextText;
    }
  }

  static void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  static String _formatAmount(num value) {
    if (!value.isFinite) return '0';

    if (value == value.roundToDouble()) {
      return value.toInt().toString();
    }

    return value.toStringAsFixed(2);
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.currencyCode,
    required this.pendingAmount,
    required this.payingMpesa,
  });

  final String currencyCode;
  final num pendingAmount;
  final bool payingMpesa;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: <Widget>[
        const Icon(Icons.phone_iphone),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Pay by M-Pesa',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Balance: $currencyCode ${_MpesaPromptPayCardState._formatAmount(pendingAmount)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (payingMpesa)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }
}
