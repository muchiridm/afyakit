// lib/features/retail/quotes/controllers/quote_action_controller.dart

import 'dart:typed_data';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';
import 'package:afyakit/core/workspace/providers/workspace_mode_provider.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/providers/zoho_quote_provider.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_open.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteActionControllerProvider =
    Provider.autoDispose<QuoteActionController>(
      (Ref ref) => QuoteActionController(ref),
    );

class QuoteActionController {
  QuoteActionController(this._ref);

  final Ref _ref;

  Future<ZohoQuotesService> get _svc async {
    return _ref.read(zohoQuotesServiceProvider.future);
  }

  // ─────────────────────────────────────────────
  // Permissions
  // ─────────────────────────────────────────────

  bool get _isStaffWorkspaceActive {
    return _ref.read(isStaffWorkspaceActiveProvider);
  }

  bool get _canViewQuotePdf {
    final me = _ref.read(currentUserProvider).valueOrNull;
    return me?.canViewQuotePdf ?? false;
  }

  bool get _canSendQuote {
    final me = _ref.read(currentUserProvider).valueOrNull;
    return _isStaffWorkspaceActive && (me?.canSendQuote ?? false);
  }

  bool get _canMarkQuoteSent {
    final me = _ref.read(currentUserProvider).valueOrNull;
    return _isStaffWorkspaceActive && (me?.canMarkQuoteSent ?? false);
  }

  bool get _canConvertQuoteToInvoice {
    final me = _ref.read(currentUserProvider).valueOrNull;
    return _isStaffWorkspaceActive && (me?.canConvertQuoteToInvoice ?? false);
  }

  bool _requireCanViewQuotePdf() {
    if (_canViewQuotePdf) return true;
    _showPermissionError();
    return false;
  }

  bool _requireCanSendQuote() {
    if (_canSendQuote) return true;
    _showPermissionError();
    return false;
  }

  bool _requireCanMarkQuoteSent() {
    if (_canMarkQuoteSent) return true;
    _showPermissionError();
    return false;
  }

  bool _requireCanConvertQuoteToInvoice() {
    if (_canConvertQuoteToInvoice) return true;
    _showPermissionError();
    return false;
  }

  void _showPermissionError() {
    SnackService.showError('You don’t have permission to perform this action.');
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  void _refreshQuote(String quoteId) {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    _ref.invalidate(zohoQuoteProvider(id));
  }

  String _friendlyError(Object error, {required String fallback}) {
    final String raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    final String cleaned = raw
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  // ─────────────────────────────────────────────
  // Public actions
  // ─────────────────────────────────────────────

  Future<void> viewPdf(BuildContext context, {required String quoteId}) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanViewQuotePdf()) return;

    try {
      final ZohoQuotesService svc = await _svc;
      final Uint8List bytes = await svc.getPdf(id);

      if (!context.mounted) return;

      if (kIsWeb) {
        openPdfBytes(bytes);
        return;
      }

      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfPreviewScreen(
            bytes: bytes,
            title: 'Quote PDF',
            fileName: 'quote_$id.pdf',
          ),
        ),
      );
    } catch (e) {
      SnackService.showError(_friendlyError(e, fallback: 'Failed to load PDF'));
    }
  }

  Future<void> sendQuote(
    BuildContext context, {
    required String quoteId,
  }) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanSendQuote()) return;

    final bool ok = await SalesDocDialogs.confirm(
      context,
      title: 'Send quote?',
      message: 'This will email the quote to the customer.',
      okLabel: 'Send',
      danger: false,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final ZohoQuotesService svc = await _svc;
      await svc.email(id);

      SnackService.showSuccess('Quote sent');
      _refreshQuote(id);
    } catch (e) {
      SnackService.showError(
        _friendlyError(e, fallback: 'Failed to send quote'),
      );
    }
  }

  Future<void> markSent(BuildContext context, {required String quoteId}) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanMarkQuoteSent()) return;

    final bool ok = await SalesDocDialogs.confirm(
      context,
      title: 'Mark as sent?',
      message: 'This will update the quote status in Zoho Books.',
      okLabel: 'Mark sent',
      danger: false,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final ZohoQuotesService svc = await _svc;
      await svc.markSent(id);

      SnackService.showSuccess('Marked as sent');
      _refreshQuote(id);
    } catch (e) {
      SnackService.showError(
        _friendlyError(e, fallback: 'Failed to mark as sent'),
      );
    }
  }

  Future<void> convertToInvoice(
    BuildContext context, {
    required String quoteId,
  }) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanConvertQuoteToInvoice()) return;

    final ZohoQuote? quote = await _readQuoteOrNull(id);

    if (quote == null) {
      SnackService.showError('Failed to load quote details.');
      return;
    }

    final String? membershipId = _clean(quote.resolvedMembershipId);
    final String? prescriptionId = _clean(quote.resolvedPrescriptionId);

    final bool isInsuranceQuote =
        quote.saleContext.isClinical && quote.paymentContext.isInsurance;

    if (isInsuranceQuote && membershipId == null) {
      SnackService.showError('This insurance quote has no membership linked.');
      return;
    }

    if (isInsuranceQuote && prescriptionId == null) {
      SnackService.showError(
        'This insurance quote has no prescription linked.',
      );
      return;
    }

    final bool ok = await SalesDocDialogs.confirm(
      context,
      title: 'Convert to invoice?',
      message: isInsuranceQuote
          ? 'This will create a Zoho invoice from this insurance quote. You can create the insurance claim pack separately after conversion.'
          : 'This will create a Zoho invoice from this quote.',
      okLabel: 'Convert',
      danger: false,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final ZohoQuotesService svc = await _svc;

      final QuoteConversionResult result = await svc.convertToInvoice(
        id,
        membershipId: membershipId,
        prescriptionId: prescriptionId,
        patientSnapshot: quote.patientSnapshot,
        deliveryAddress: quote.deliveryAddress,
      );

      SnackService.showSuccess(_conversionMessage(result));
      _refreshQuote(id);
    } catch (e) {
      SnackService.showError(
        _friendlyError(e, fallback: 'Failed to convert to invoice'),
      );
    }
  }

  Future<void> refresh(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    _refreshQuote(id);
    await _ref.read(zohoQuoteProvider(id).future);
  }

  Future<ZohoQuote?> _readQuoteOrNull(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) return null;

    try {
      return await _ref.read(zohoQuoteProvider(id).future);
    } catch (_) {
      return null;
    }
  }

  static String _conversionMessage(QuoteConversionResult result) {
    final String? invoiceNumber = _readInvoiceString(
      result.invoice,
      'invoice_number',
      fallbackKey: 'invoiceNumber',
    );

    final String? invoiceId = _readInvoiceString(
      result.invoice,
      'invoice_id',
      fallbackKey: 'invoiceId',
    );

    final String invoiceLabel = invoiceNumber ?? invoiceId ?? '';

    if (invoiceLabel.isNotEmpty) {
      return 'Converted → Invoice $invoiceLabel';
    }

    return 'Converted to invoice';
  }

  static String? _readInvoiceString(
    Map<String, Object?> invoice,
    String key, {
    required String fallbackKey,
  }) {
    final Object? value = invoice[key] ?? invoice[fallbackKey];
    final String text = (value ?? '').toString().trim();

    return text.isEmpty ? null : text;
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
