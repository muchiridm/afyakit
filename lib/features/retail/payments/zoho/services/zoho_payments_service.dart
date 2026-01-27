// lib/features/retail/sales/payments/services/zoho_payments_service.dart

import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../../../shared/models/zoho_payment_draft.dart';
import '../../../shared/models/zoho_invoice_payment.dart';
import '../../../shared/models/zoho_payment_dtos.dart';

final zohoPaymentsServiceProvider = FutureProvider<ZohoPaymentsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientProvider.future);
  return ZohoPaymentsService(api: api, routes: routes);
});

class ZohoPaymentsService {
  ZohoPaymentsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  // ─────────────────────────────────────────────
  // Invoice-scoped convenience (via payments router + invoice_id query)
  // GET /zoho/v1/payments?invoice_id=...&per_page=...&page=...
  // ─────────────────────────────────────────────

  Future<ListInvoicePaymentsResult> listInvoicePaymentsWithBalance(
    String invoiceId, {
    int perPage = 200,
    int page = 1,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.zohoInvoicePayments(id, perPage: perPage, page: page);

    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);

    final rawPays =
        data['payments'] ??
        data['customerpayments'] ??
        data['payment_details'] ??
        data['items'];

    final pays = _parsePaymentsList(rawPays);

    final rawInv = data['invoice'];
    final invSummary = rawInv is Map
        ? InvoiceBalanceSummary.fromJson(rawInv.cast<String, dynamic>())
        : InvoiceBalanceSummary(invoiceId: id);

    return ListInvoicePaymentsResult(payments: pays, invoice: invSummary);
  }

  Future<List<ZohoInvoicePayment>> listInvoicePayments(
    String invoiceId, {
    int perPage = 200,
    int page = 1,
  }) async {
    final r = await listInvoicePaymentsWithBalance(
      invoiceId,
      perPage: perPage,
      page: page,
    );
    return r.payments;
  }

  // ─────────────────────────────────────────────
  // Payments list (optionally invoice-filtered)
  // GET /zoho/v1/payments?invoice_id=&per_page=&page=
  // ─────────────────────────────────────────────

  Future<List<ZohoInvoicePayment>> list({
    int perPage = 200,
    int page = 1,
    String? invoiceId,
  }) async {
    final uri = routes.zohoPaymentsList(
      perPage: perPage,
      page: page,
      invoiceId: invoiceId,
    );

    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['payments'] ?? data['customerpayments'] ?? data['items'];

    return _parsePaymentsList(raw);
  }

  // ─────────────────────────────────────────────
  // ✅ NEW: Get payment details (by paymentId)
  // GET /zoho/v1/payments/:paymentId
  // ─────────────────────────────────────────────

  Future<JsonMap> getRaw(String paymentId) async {
    final id = paymentId.trim();
    if (id.isEmpty) throw ArgumentError('paymentId is empty');

    final uri = routes.zohoPaymentsGet(id);
    final res = await api.getUri(uri);
    return _asJsonMap(res.data);
  }

  /// Optional convenience: parse a payment object if backend returns one.
  Future<ZohoInvoicePayment?> get(String paymentId) async {
    final data = await getRaw(paymentId);

    final rawPayment =
        data['payment'] ??
        data['customerpayment'] ??
        data['customer_payment'] ??
        data['data'];

    if (rawPayment is! Map) return null;
    return ZohoInvoicePayment.fromJson(rawPayment.cast<String, dynamic>());
  }

  /// ✅ KEY FIX for PaymentsListScreen:
  /// list() rows often lack invoice_id. Resolve it from payment details.
  Future<String?> resolveInvoiceIdForPayment(String paymentId) async {
    final data = await getRaw(paymentId);

    final root = (data['customerpayment'] is Map)
        ? data['customerpayment']
        : (data['payment'] is Map)
        ? data['payment']
        : (data['data'] is Map)
        ? data['data']
        : null;

    if (root is! Map) return null;

    // Sometimes direct
    final direct = (root['invoice_id'] ?? root['invoiceId'] ?? '')
        .toString()
        .trim();
    if (direct.isNotEmpty) return direct;

    // Most common: invoices allocations
    final fromInvoices = _firstInvoiceIdFromList(root['invoices']);
    if (fromInvoices != null) return fromInvoices;

    // Some payloads: invoice_payments allocations
    final fromInvoicePayments = _firstInvoiceIdFromList(
      root['invoice_payments'],
    );
    if (fromInvoicePayments != null) return fromInvoicePayments;

    return null;
  }

  static String? _firstInvoiceIdFromList(Object? v) {
    if (v is! List) return null;
    for (final row in v) {
      if (row is Map) {
        final inv = (row['invoice_id'] ?? row['invoiceId'] ?? '')
            .toString()
            .trim();
        if (inv.isNotEmpty) return inv;
      }
    }
    return null;
  }

  // ─────────────────────────────────────────────
  // Create / Update / Delete
  // ─────────────────────────────────────────────

  Future<ZohoInvoicePayment> create(ZohoPaymentDraft draft) async {
    final uri = routes.zohoPaymentsCreate();

    final res = await api.postUri(uri, data: draft.withDateOnly().toJson());

    final data = _asJsonMap(res.data);

    final rawPayment =
        data['payment'] ?? data['customerpayment'] ?? data['data'];

    if (rawPayment is! Map) {
      throw StateError('Unexpected response shape: missing payment object');
    }

    return ZohoInvoicePayment.fromJson(rawPayment.cast<String, dynamic>());
  }

  Future<ZohoInvoicePayment> update(
    String paymentId,
    ZohoPaymentDraft draft,
  ) async {
    final id = paymentId.trim();
    if (id.isEmpty) throw ArgumentError('paymentId is empty');

    final uri = routes.zohoPaymentsUpdate(id);

    final res = await api.putUri(uri, data: draft.withDateOnly().toJson());

    final data = _asJsonMap(res.data);

    final rawPayment =
        data['payment'] ?? data['customerpayment'] ?? data['data'];

    if (rawPayment is! Map) {
      throw StateError('Unexpected response shape: missing payment object');
    }

    return ZohoInvoicePayment.fromJson(rawPayment.cast<String, dynamic>());
  }

  Future<void> remove(String paymentId) async {
    final id = paymentId.trim();
    if (id.isEmpty) throw ArgumentError('paymentId is empty');

    final uri = routes.zohoPaymentsDelete(id);
    await api.deleteUri(uri);
  }

  // ───────────────────────────────────────── Helpers ─────────────────────────────────────────

  static List<ZohoInvoicePayment> _parsePaymentsList(Object? raw) {
    if (raw is! List) return const <ZohoInvoicePayment>[];

    final out = <ZohoInvoicePayment>[];
    for (final e in raw) {
      if (e is Map) {
        out.add(ZohoInvoicePayment.fromJson(e.cast<String, dynamic>()));
      }
    }
    return out;
  }

  static JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
