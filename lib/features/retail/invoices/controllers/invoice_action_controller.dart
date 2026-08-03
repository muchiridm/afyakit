// lib/features/retail/invoices/controllers/invoice_action_controller.dart

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';

import 'package:afyakit/features/retail/invoices/controllers/invoice_controller.dart';
import 'package:afyakit/features/retail/payments/controllers/payment_controller.dart';
import 'package:afyakit/features/retail/payments/widgets/payment_editor_sheet.dart';
import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';

import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_open.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';

final invoiceActionControllerProvider =
    Provider.autoDispose<InvoiceActionController>((ref) {
      return InvoiceActionController(ref);
    });

class InvoiceActionController {
  InvoiceActionController(this._ref);

  final Ref _ref;

  InvoiceController get _ctl => _ref.read(invoiceControllerProvider.notifier);

  bool get _canManageInvoices {
    final me = _ref.read(currentUserProvider).valueOrNull;
    return me?.canManageInvoices ?? false;
  }

  bool _requireCanManageInvoices() {
    if (_canManageInvoices) return true;

    SnackService.showError('You don’t have permission to perform this action.');
    return false;
  }

  // ─────────────────────────────────────────────
  // PDF
  // ─────────────────────────────────────────────

  /// Dumb UI calls this.
  /// - Web: opens immediately in new tab
  /// - Mobile/Desktop: opens PdfPreviewScreen
  Future<void> viewPdf(
    BuildContext context, {
    required String invoiceId,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;

    try {
      final Uint8List? bytes = await _ctl.getInvoicePdfBytes(id);
      if (bytes == null) return;
      if (!context.mounted) return;

      if (kIsWeb) {
        openPdfBytes(bytes);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfPreviewScreen(
            bytes: bytes,
            title: 'Invoice PDF',
            fileName: 'invoice_$id.pdf',
          ),
        ),
      );
    } catch (_) {
      SnackService.showError('Failed to load PDF');
    }
  }

  // ─────────────────────────────────────────────
  // Refresh
  // ─────────────────────────────────────────────

  Future<void> refresh(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;

    await _ctl.load(id);
  }

  // ─────────────────────────────────────────────
  // Mutations / staff actions
  // ─────────────────────────────────────────────

  Future<void> sendInvoice(
    BuildContext context, {
    required String invoiceId,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;

    if (!_requireCanManageInvoices()) return;

    final ok = await DialogService.confirm(
      context: context,
      title: 'Send invoice?',
      content: 'This will email the invoice to the customer.',
      confirmText: 'Send',
      confirmColor: Colors.blue,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      await _ensureInvoiceLoaded(id);

      final inv = _ref.read(invoiceControllerProvider).invoice;
      if (inv == null) {
        SnackService.showError('Invoice not loaded');
        return;
      }

      final email = ZohoEmailDraft(
        contactPersonIds: inv.contactPersonIds,
        subject: 'Invoice ${inv.invoiceNumber ?? inv.invoiceId}',
        body: 'Please find your invoice attached.',
      );

      final sent = await _ctl.sendInvoice(id, email: email);
      if (!sent) return;

      await _ctl.load(id);
    } catch (e) {
      SnackService.showError(e.toString());
    }
  }

  Future<void> markSent(
    BuildContext context, {
    required String invoiceId,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;

    if (!_requireCanManageInvoices()) return;

    final ok = await DialogService.confirm(
      context: context,
      title: 'Mark as sent?',
      content: 'This will update the invoice status in Zoho Books.',
      confirmText: 'Mark sent',
      confirmColor: Colors.blue,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final done = await _ctl.markInvoiceSent(id);
      if (!done) return;

      await _ctl.load(id);
    } catch (e) {
      SnackService.showError(e.toString());
    }
  }

  /// Records a normal Zoho customer payment against the invoice.
  ///
  /// This is the correct generic "mark as paid" flow because it supports:
  /// - Cash
  /// - Bank transfer
  /// - Card
  /// - Insurance
  /// - M-Pesa
  /// - Other modes
  ///
  /// The payment editor handles payment_mode/reference/notes/date/amount.
  Future<void> recordPayment(
    BuildContext context, {
    required String invoiceId,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;

    if (!_requireCanManageInvoices()) return;

    try {
      await _ensureInvoiceLoaded(id);

      final inv = _ref.read(invoiceControllerProvider).invoice;
      if (inv == null) {
        SnackService.showError('Invoice not loaded');
        return;
      }

      final pending = _validPending(inv.balance);
      if (pending == null) {
        SnackService.showSuccess('Invoice has no outstanding balance.');
        return;
      }

      final paymentCtl = _ref.read(paymentControllerProvider(id).notifier);

      paymentCtl.startNewPayment();
      paymentCtl.seedFromInvoiceContext(
        pendingAmount: pending,
        suggestedPhone: null,
      );

      if (!context.mounted) return;

      await PaymentEditorSheet.open(context, invoiceId: id);

      await _ctl.load(id);
      await paymentCtl.refresh();
    } catch (e) {
      SnackService.showError(e.toString());
    }
  }

  Future<void> _ensureInvoiceLoaded(String invoiceId) async {
    final currentId =
        (_ref.read(invoiceControllerProvider).invoice?.invoiceId ?? '').trim();

    if (currentId == invoiceId) return;

    await _ctl.load(invoiceId);
  }

  static num? _validPending(num? value) {
    if (value == null) return null;
    if (!value.isFinite) return null;
    if (value <= 0) return null;

    return value;
  }
}
