// lib/features/retail/payments/controllers/payments_by_invoice_controller.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/invoices/controllers/invoices_list_controller.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/shared/state/paged_query_controller.dart';

final paymentsByInvoiceControllerProvider = StateNotifierProvider.autoDispose
    .family<
      PaymentsByInvoiceController,
      PagedQueryState<ZohoInvoice>,
      RetailDocScope
    >((ref, scope) {
      final controller = PaymentsByInvoiceController(ref, scope: scope);
      controller.refresh(reset: true);
      return controller;
    });

class PaymentsByInvoiceController extends InvoicesListController {
  PaymentsByInvoiceController(super.ref, {required super.scope});
}
