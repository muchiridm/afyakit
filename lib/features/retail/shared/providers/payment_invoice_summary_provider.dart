import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/invoices/services/zoho_invoices_service.dart';

/// Cached per invoiceId by Riverpod.
/// Used by payments UI to show customer name / invoice number without
/// bloating the payment list DTO.
final paymentInvoiceSummaryProvider =
    FutureProvider.family<ZohoInvoice, String>((ref, invoiceId) async {
      final id = invoiceId.trim();
      if (id.isEmpty) {
        throw StateError('invoiceId is empty');
      }
      final svc = await ref.read(zohoInvoicesServiceProvider.future);
      return svc.get(id); // assumes you already have get(invoiceId)
    });
