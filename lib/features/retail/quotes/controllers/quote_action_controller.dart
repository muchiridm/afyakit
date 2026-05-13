// lib/features/retail/quotes/controllers/quote_action_controller.dart

import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';
import 'package:afyakit/core/auth/auth_user/providers/current_users_providers.dart';

import 'package:afyakit/features/retail/quotes/providers/zoho_quote_provider.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';

import 'package:afyakit/features/retail/shared/sales_doc/dialogs.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_open.dart';
import 'package:afyakit/shared/widgets/pdf/pdf_preview_screen.dart';

/// UI-facing controller:
/// - Enforces capability gate for staff-only actions
/// - Runs confirm dialogs
/// - Calls Zoho service
/// - Invalidates quote provider after mutations
///
/// ✅ Keeps screens dumb: screen just calls controller methods.
final quoteActionControllerProvider =
    Provider.autoDispose<QuoteActionController>((ref) {
      return QuoteActionController(ref);
    });

class QuoteActionController {
  QuoteActionController(this._ref);

  final Ref _ref;

  bool get _canManageQuotes {
    final me = _ref.read(currentUserProvider).valueOrNull;
    return me?.canManageQuotes ?? false;
  }

  bool _requireCanManageQuotes() {
    if (_canManageQuotes) return true;
    SnackService.showError('You don’t have permission to perform this action.');
    return false;
  }

  void _refreshQuote(String quoteId) {
    _ref.invalidate(zohoQuoteProvider(quoteId));
  }

  Future<ZohoQuotesService> _svc() async {
    return _ref.read(zohoQuotesServiceProvider.future);
  }

  // ─────────────────────────────────────────────
  // Public actions (call from UI)
  // ─────────────────────────────────────────────

  Future<void> viewPdf(BuildContext context, {required String quoteId}) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    try {
      final svc = await _svc();
      final Uint8List bytes = await svc.getPdf(id);

      if (!context.mounted) return;

      if (kIsWeb) {
        // ✅ Web: open immediately in new tab (no extra screen)
        openPdfBytes(bytes);
        return;
      }

      // ✅ Mobile/Desktop: keep in-app preview
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => PdfPreviewScreen(
            bytes: bytes,
            title: 'Quote PDF',
            fileName: 'quote_$id.pdf',
          ),
        ),
      );
    } catch (_) {
      SnackService.showError('Failed to load PDF');
    }
  }

  Future<void> sendQuote(
    BuildContext context, {
    required String quoteId,
  }) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanManageQuotes()) return;

    final ok = await SalesDocDialogs.confirm(
      context,
      title: 'Send quote?',
      message: 'This will email the quote to the customer.',
      okLabel: 'Send',
      danger: false,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final svc = await _svc();
      await svc.email(id);

      SnackService.showSuccess('Quote sent');
      _refreshQuote(id);
    } catch (_) {
      SnackService.showError('Failed to send quote');
    }
  }

  Future<void> markSent(BuildContext context, {required String quoteId}) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanManageQuotes()) return;

    final ok = await SalesDocDialogs.confirm(
      context,
      title: 'Mark as sent?',
      message: 'This will update the quote status in Zoho Books.',
      okLabel: 'Mark sent',
      danger: false,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final svc = await _svc();
      await svc.markSent(id);

      SnackService.showSuccess('Marked as sent');
      _refreshQuote(id);
    } catch (_) {
      SnackService.showError('Failed to mark as sent');
    }
  }

  Future<void> convertToInvoice(
    BuildContext context, {
    required String quoteId,
  }) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    if (!_requireCanManageQuotes()) return;

    final quote = await _readQuoteOrNull(id);

    final membershipId = quote?.resolvedMembershipId;
    final hasInsuranceContext = (membershipId ?? '').trim().isNotEmpty;

    final ok = await SalesDocDialogs.confirm(
      context,
      title: hasInsuranceContext
          ? 'Convert to invoice and create claim?'
          : 'Convert to invoice?',
      message: hasInsuranceContext
          ? 'This will create an invoice from this quote in Zoho Books and create an insurance claim linked to that invoice.'
          : 'This will create an invoice from this quote in Zoho Books.',
      okLabel: 'Convert',
      danger: false,
      barrierDismissible: false,
    );

    if (!ok) return;

    try {
      final svc = await _svc();

      final result = await svc.convertToInvoice(
        id,
        membershipId: membershipId,
        patientSnapshot: quote?.patientSnapshot,
        createInsuranceClaim: hasInsuranceContext,
      );

      final invoiceId = _readInvoiceString(
        result.invoice,
        'invoice_id',
        fallbackKey: 'invoiceId',
      );

      final invoiceNumber = _readInvoiceString(
        result.invoice,
        'invoice_number',
        fallbackKey: 'invoiceNumber',
      );

      if (result.claim != null) {
        if (invoiceNumber != null) {
          SnackService.showSuccess(
            'Converted → Invoice $invoiceNumber and claim created',
          );
        } else if (invoiceId != null) {
          SnackService.showSuccess(
            'Converted → Invoice $invoiceId and claim created',
          );
        } else {
          SnackService.showSuccess('Converted to invoice and claim created');
        }
      } else if (invoiceNumber != null) {
        SnackService.showSuccess('Converted → Invoice $invoiceNumber');
      } else if (invoiceId != null) {
        SnackService.showSuccess('Converted → Invoice $invoiceId');
      } else {
        SnackService.showSuccess('Converted to invoice');
      }

      _refreshQuote(id);
    } catch (_) {
      SnackService.showError('Failed to convert to invoice');
    }
  }

  /// Used by UI pull-to-refresh.
  Future<void> refresh(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;

    _refreshQuote(id);
    await _ref.read(zohoQuoteProvider(id).future);
  }

  Future<dynamic> _readQuoteOrNull(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) return null;

    try {
      return await _ref.read(zohoQuoteProvider(id).future);
    } catch (_) {
      return null;
    }
  }

  static String? _readInvoiceString(
    Map<String, Object?> invoice,
    String key, {
    required String fallbackKey,
  }) {
    final value = invoice[key] ?? invoice[fallbackKey];
    final text = (value ?? '').toString().trim();

    return text.isEmpty ? null : text;
  }
}
