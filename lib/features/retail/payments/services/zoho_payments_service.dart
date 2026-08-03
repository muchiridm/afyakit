// lib/features/retail/payments/services/zoho_payments_service.dart

import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/retail/payments/models/zoho_invoice_payment.dart';
import 'package:afyakit/features/retail/payments/models/zoho_payment_draft.dart';
import 'package:afyakit/features/retail/payments/models/zoho_payment_dtos.dart';

final zohoPaymentsServiceProvider = FutureProvider<ZohoPaymentsService>((
  Ref ref,
) async {
  final String tenantId = ref.watch(tenantIdProvider);
  final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
  final AfyaKitClient api = await ref.watch(afyakitClientFutureProvider.future);

  return ZohoPaymentsService(api: api, routes: routes);
});

class ZohoPaymentsService {
  ZohoPaymentsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<ListInvoicePaymentsResult> listInvoicePaymentsWithBalance(
    String invoiceId, {
    int perPage = 100,
    int page = 1,
  }) async {
    final String id = invoiceId.trim();

    if (id.isEmpty) {
      throw ArgumentError('invoiceId is empty');
    }

    final Uri uri = routes.retailInvoicePayments(
      id,
      perPage: perPage,
      page: page,
    );

    final res = await api.getUri(uri);
    final JsonMap data = _asJsonMap(res.data);

    final Object? rawPayments =
        data['payments'] ??
        data['customerpayments'] ??
        data['payment_details'] ??
        data['items'];

    final List<ZohoInvoicePayment> payments = _parsePaymentsList(rawPayments);

    final Object? rawInvoice = data['invoice'];

    final InvoiceBalanceSummary invoice = rawInvoice is Map
        ? InvoiceBalanceSummary.fromJson(rawInvoice.cast<String, dynamic>())
        : InvoiceBalanceSummary(invoiceId: id);

    return ListInvoicePaymentsResult(payments: payments, invoice: invoice);
  }

  Future<List<ZohoInvoicePayment>> listInvoicePayments(
    String invoiceId, {
    int perPage = 100,
    int page = 1,
  }) async {
    final ListInvoicePaymentsResult result =
        await listInvoicePaymentsWithBalance(
          invoiceId,
          perPage: perPage,
          page: page,
        );

    return result.payments;
  }

  Future<JsonMap> getRaw(String paymentId) async {
    final String id = paymentId.trim();

    if (id.isEmpty) {
      throw ArgumentError('paymentId is empty');
    }

    final Uri uri = routes.retailPaymentsGet(id);
    final res = await api.getUri(uri);

    return _asJsonMap(res.data);
  }

  Future<ZohoInvoicePayment?> get(String paymentId) async {
    final JsonMap data = await getRaw(paymentId);

    final Object? rawPayment =
        data['payment'] ??
        data['customerpayment'] ??
        data['customer_payment'] ??
        data['data'];

    if (rawPayment is! Map) return null;

    return ZohoInvoicePayment.fromJson(rawPayment.cast<String, dynamic>());
  }

  Future<ZohoInvoicePayment> create(ZohoPaymentDraft draft) async {
    draft.assertValidCreate();

    final Uri uri = routes.retailPaymentsCreate();

    final res = await api.postUri(
      uri,
      data: draft.withDateOnly().toCreateJson(),
    );

    final JsonMap data = _asJsonMap(res.data);

    final Object? rawPayment =
        data['payment'] ??
        data['customerpayment'] ??
        data['customer_payment'] ??
        data['data'];

    if (rawPayment is! Map) {
      throw StateError('Unexpected response shape: missing payment object');
    }

    return ZohoInvoicePayment.fromJson(rawPayment.cast<String, dynamic>());
  }

  Future<ZohoInvoicePayment> update(
    String paymentId,
    ZohoPaymentDraft draft,
  ) async {
    final String id = paymentId.trim();

    if (id.isEmpty) {
      throw ArgumentError('paymentId is empty');
    }

    draft.assertValidUpdate();

    final Uri uri = routes.retailPaymentsUpdate(id);

    final res = await api.putUri(
      uri,
      data: draft.withDateOnly().toUpdateJson(),
    );

    final JsonMap data = _asJsonMap(res.data);

    final Object? rawPayment =
        data['payment'] ??
        data['customerpayment'] ??
        data['customer_payment'] ??
        data['data'];

    if (rawPayment is! Map) {
      throw StateError('Unexpected response shape: missing payment object');
    }

    return ZohoInvoicePayment.fromJson(rawPayment.cast<String, dynamic>());
  }

  Future<void> remove(String paymentId) async {
    final String id = paymentId.trim();

    if (id.isEmpty) {
      throw ArgumentError('paymentId is empty');
    }

    final Uri uri = routes.retailPaymentsDelete(id);
    await api.deleteUri(uri);
  }

  static List<ZohoInvoicePayment> _parsePaymentsList(Object? raw) {
    if (raw is! List) {
      return const <ZohoInvoicePayment>[];
    }

    final List<ZohoInvoicePayment> out = <ZohoInvoicePayment>[];

    for (final Object? row in raw) {
      if (row is! Map) continue;

      out.add(ZohoInvoicePayment.fromJson(row.cast<String, dynamic>()));
    }

    return out;
  }

  static JsonMap _asJsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();

    throw StateError('Expected JSON object but got ${value.runtimeType}');
  }
}
