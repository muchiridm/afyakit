// lib/features/retail/payments/zoho/widgets/payment_footer.dart

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

    // Preload helpers (from invoice + contact already on page)
    this.pendingAmount,
    this.suggestedPhone,

    // Callback to reload invoice / parent after successful payment mutations
    this.onPaymentSuccess,
  });

  final String currencyCode;
  final String invoiceId;
  final bool canManageInvoices;

  final String? customerName;
  final String? invoiceNumber;
  final DateTime? invoiceDate;
  final num? invoiceTotal;

  /// ✅ invoice.balance (balance due / pending)
  final num? pendingAmount;

  /// ✅ best phone from invoice/contact context
  final String? suggestedPhone;

  /// ✅ parent hook (invoice reload). Called after payment mutation + refresh.
  final Future<void> Function()? onPaymentSuccess;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invId = invoiceId.trim();
    if (invId.isEmpty) return const SizedBox.shrink();

    final s = ref.watch(paymentControllerProvider(invId));
    final ctl = ref.read(paymentControllerProvider(invId).notifier);

    final num? pending =
        _normPending(s.pendingAmount) ?? _normPending(pendingAmount);
    final String? phoneHint =
        _normPhone(s.suggestedMpesaPhone) ?? _normPhone(suggestedPhone);

    final bool busy = s.busy;
    final bool hasBalance = pending != null && pending > 0;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Divider(height: 1),

        if (hasBalance)
          _buildMpesaCard(
            context: context,
            pending: pending,
            phoneHint: phoneHint,
            busy: busy,
            payingMpesa: s.payingMpesa,
            mpesaStatusText: _mpesaStatusText(s.mpesaLastPayment),
            onPay: (!busy && !s.payingMpesa)
                ? (phone, amount) => _handleMpesaPay(
                    ctl: ctl,
                    phone: phone,
                    amount: amount,
                    pending: pending,
                    phoneHint: phoneHint,
                  )
                : null,
          ),

        _buildHistory(context: context, ctl: ctl, invId: invId, busy: busy),
      ],
    );
  }

  // ─────────────────────────────
  // Private builders
  // ─────────────────────────────

  Widget _buildMpesaCard({
    required BuildContext context,
    required num pending,
    required String? phoneHint,
    required bool busy,
    required bool payingMpesa,
    required String? mpesaStatusText,
    required Future<void> Function(String phone, num amount)? onPay,
  }) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      child: _MpesaPromptPayCard(
        currencyCode: currencyCode,
        pendingAmount: pending,
        phoneHint: phoneHint,
        busy: busy,
        payingMpesa: payingMpesa,
        mpesaStatusText: mpesaStatusText,
        onPay: onPay,
      ),
    );
  }

  Widget _buildHistory({
    required BuildContext context,
    required PaymentController ctl,
    required String invId,
    required bool busy,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: PaymentHistorySection(
        currencyCode: currencyCode,
        invoiceId: invId,
        onRefresh: ctl.refresh,
        canManage: canManageInvoices,

        // Staff-only manual record
        onRecord: (!canManageInvoices || busy)
            ? null
            : () => _handleStaffRecord(context, ctl, invId),

        maxRows: 4,
        onOpenReceipt: (p) => _openReceipt(context, p),

        // Staff-only edit/delete
        onEdit: canManageInvoices && !busy
            ? (p) => _handleStaffEdit(context, ctl, invId, p)
            : null,

        onDelete: canManageInvoices && !busy
            ? (p) => _handleStaffDelete(context, ctl, p)
            : null,
      ),
    );
  }

  // ─────────────────────────────
  // Actions (DRY)
  // ─────────────────────────────

  Future<void> _handleMpesaPay({
    required PaymentController ctl,
    required String phone,
    required num amount,
    required num? pending,
    required String? phoneHint,
  }) async {
    // Seed draft hints (no network)
    ctl.seedFromInvoiceContext(
      pendingAmount: pending,
      suggestedPhone: phoneHint,
    );

    await ctl.payViaMpesaStk(phone: phone, amount: amount);

    // Reload payment list for history
    await ctl.refresh();

    // Reload invoice / parent (so footer can disappear if balance cleared)
    await onPaymentSuccess?.call();
  }

  Future<void> _handleStaffRecord(
    BuildContext context,
    PaymentController ctl,
    String invId,
  ) async {
    ctl.startNewPayment();

    // Seed from parent context (no network)
    ctl.seedFromInvoiceContext(
      pendingAmount: pendingAmount,
      suggestedPhone: suggestedPhone,
    );

    await PaymentEditorSheet.open(context, invoiceId: invId);

    await ctl.refresh();
    await onPaymentSuccess?.call();
  }

  Future<void> _handleStaffEdit(
    BuildContext context,
    PaymentController ctl,
    String invId,
    ZohoInvoicePayment p,
  ) async {
    ctl.startEditPayment(p);

    ctl.seedFromInvoiceContext(
      pendingAmount: pendingAmount,
      suggestedPhone: suggestedPhone,
    );

    await PaymentEditorSheet.open(context, invoiceId: invId);

    await ctl.refresh();
    await onPaymentSuccess?.call();
  }

  Future<void> _handleStaffDelete(
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

    await ctl.refresh();
    await onPaymentSuccess?.call();
  }

  void _openReceipt(BuildContext context, ZohoInvoicePayment p) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PaymentDetailScreen(
          invoiceId: invoiceId,
          currencyCode: currencyCode,
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

  // ─────────────────────────────
  // Small helpers
  // ─────────────────────────────

  static num? _normPending(num? v) {
    if (v == null) return null;
    if (!v.isFinite) return null;
    if (v <= 0) return null;
    return v;
  }

  static String? _normPhone(String? v) {
    final s = (v ?? '').trim();
    return s.isEmpty ? null : s;
  }

  static String? _mpesaStatusText(Object? last) {
    if (last == null) return null;

    // Keep loosely typed: controller owns actual mpesa models.
    try {
      final d = last as dynamic;

      final desc = (d.resultDesc ?? '').toString().trim();
      final status = (d.status ?? '').toString().trim();
      final code = (d.resultCode ?? '').toString().trim();

      final parts = <String>[];
      if (status.isNotEmpty) parts.add(status);
      if (code.isNotEmpty) parts.add('($code)');
      if (desc.isNotEmpty) parts.add(desc);

      final out = parts.join(' ');
      return out.isEmpty ? null : out;
    } catch (_) {
      return null;
    }
  }
}

// ─────────────────────────────
// M-Pesa card (partial payments)
// ─────────────────────────────

typedef MpesaPayFn = Future<void> Function(String phone, num amount);

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

  /// If null => disabled
  final MpesaPayFn? onPay;

  @override
  State<_MpesaPromptPayCard> createState() => _MpesaPromptPayCardState();
}

class _MpesaPromptPayCardState extends State<_MpesaPromptPayCard> {
  late final TextEditingController _phoneCtl;
  late final TextEditingController _amountCtl;

  @override
  void initState() {
    super.initState();
    _phoneCtl = TextEditingController(text: widget.phoneHint ?? '');
    _amountCtl = TextEditingController(text: _fmt(widget.pendingAmount));
  }

  @override
  void didUpdateWidget(covariant _MpesaPromptPayCard oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Seed phone only if user hasn't typed anything.
    final curPhone = _phoneCtl.text.trim();
    final nextPhone = (widget.phoneHint ?? '').trim();
    if (curPhone.isEmpty && nextPhone.isNotEmpty) {
      _phoneCtl.text = nextPhone;
    }

    // Seed amount only if user hasn't edited it (still equals old pending).
    final curAmt = _amountCtl.text.trim();
    final oldPendingText = _fmt(oldWidget.pendingAmount).trim();
    final newPendingText = _fmt(widget.pendingAmount).trim();

    if (curAmt == oldPendingText && newPendingText != oldPendingText) {
      _amountCtl.text = newPendingText;
    }
  }

  @override
  void dispose() {
    _phoneCtl.dispose();
    _amountCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pending = widget.pendingAmount;
    final canPay =
        widget.onPay != null &&
        !widget.busy &&
        !widget.payingMpesa &&
        pending > 0;

    return Card(
      elevation: 0,
      color: Theme.of(context).colorScheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(context, pending),
            const SizedBox(height: 10),
            _buildPhoneField(),
            const SizedBox(height: 10),
            _buildAmountField(pending),
            _buildStatusText(context),
            const SizedBox(height: 10),
            _buildPayButton(context, canPay, pending),
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

  Widget _buildHeader(BuildContext context, num pending) {
    return Row(
      children: [
        const Icon(Icons.phone_iphone),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pay by M-Pesa (STK Prompt)',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 2),
              Text(
                'Balance: ${widget.currencyCode} ${_fmt(pending)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (widget.payingMpesa) const SizedBox(width: 8),
        if (widget.payingMpesa)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return TextField(
      controller: _phoneCtl,
      keyboardType: TextInputType.phone,
      enabled: !widget.busy && !widget.payingMpesa,
      decoration: const InputDecoration(
        labelText: 'Phone (M-Pesa)',
        hintText: '07XXXXXXXX / 01XXXXXXXX / 2547XXXXXXXX / 2541XXXXXXXX',
        prefixIcon: Icon(Icons.call_outlined),
        border: OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildAmountField(num pending) {
    return TextField(
      controller: _amountCtl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      enabled: !widget.busy && !widget.payingMpesa,
      decoration: InputDecoration(
        labelText: 'Amount',
        hintText: _fmt(pending),
        prefixIcon: const Icon(Icons.payments_outlined),
        border: const OutlineInputBorder(),
        isDense: true,
      ),
    );
  }

  Widget _buildStatusText(BuildContext context) {
    final t = (widget.mpesaStatusText ?? '').trim();
    if (t.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(t, style: Theme.of(context).textTheme.bodySmall),
    );
  }

  Widget _buildPayButton(BuildContext context, bool canPay, num pending) {
    return ElevatedButton.icon(
      onPressed: canPay ? () => _submit(context, pending) : null,
      icon: const Icon(Icons.payments_outlined),
      label: Text(widget.payingMpesa ? 'Prompting…' : 'Prompt & Pay'),
    );
  }

  Future<void> _submit(BuildContext context, num pending) async {
    final phone = _phoneCtl.text.trim();
    if (phone.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter your M-Pesa phone number')),
      );
      return;
    }

    final raw = _amountCtl.text.trim();
    final amount = num.tryParse(raw);

    if (amount == null || amount <= 0) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Enter a valid amount')));
      return;
    }

    if (amount > pending) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Amount cannot exceed balance (${_fmt(pending)})'),
        ),
      );
      return;
    }

    await widget.onPay!(phone, amount);
  }

  static String _fmt(num v) {
    if (!v.isFinite) return '0';
    if (v == v.roundToDouble()) return v.toInt().toString();
    return v.toStringAsFixed(2);
  }
}
