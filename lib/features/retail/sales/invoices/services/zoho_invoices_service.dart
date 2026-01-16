// lib/features/retail/sales/invoices/services/zoho_invoices_service.dart

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../models/payment_draft.dart';
import '../models/zoho_invoice.dart';
import '../models/zoho_invoice_payment.dart';

typedef JsonMap = Map<String, dynamic>;

final zohoInvoicesServiceProvider = FutureProvider<ZohoInvoicesService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientProvider.future);
  return ZohoInvoicesService(api: api, routes: routes);
});

class ZohoInvoicesService {
  ZohoInvoicesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static final DateFormat _zohoDateFmt = DateFormat('yyyy-MM-dd');

  // ───────────────────────── Read ─────────────────────────

  Future<List<ZohoInvoice>> list({int limit = 50, int page = 1}) async {
    final uri = routes.zohoListInvoices(limit: limit, page: page);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['invoices'] ?? data['items'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ZohoInvoice.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return const <ZohoInvoice>[];
  }

  Future<ZohoInvoice> get(String invoiceId) async {
    final raw = await getInvoice(invoiceId);
    return ZohoInvoice.fromJson(raw);
  }

  Future<JsonMap> getInvoice(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.zohoGetInvoice(id);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['invoice'] ?? data;

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();

    throw StateError('Unexpected response shape: missing invoice object');
  }

  /// Optional tiny patcher (notes/terms/reference) if you still want it.
  /// If you truly want invoices read-only, you can delete this method.
  Future<JsonMap> updateInvoice(String invoiceId, JsonMap patch) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.zohoUpdateInvoice(id);
    final res = await api.putUri(uri, data: patch);
    return _asJsonMap(res.data);
  }

  // ───────────────────────── PDF ─────────────────────────

  /// ✅ Fetch invoice PDF bytes for PdfPreviewScreen.
  ///
  /// This should hit your backend route that proxies Zoho Books invoice PDF.
  /// Expected response: application/pdf (raw bytes).
  Future<Uint8List> getPdf(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.zohoInvoicePdf(id);

    final res = await api.getUri(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        // Optional: if your backend returns 404 while you rollout, you can
        // soften this like you did for payments. But for PDF, I prefer failing loudly.
      ),
    );

    final data = res.data;
    if (data is List<int>) return Uint8List.fromList(data);

    throw StateError('Unexpected PDF response type: ${data.runtimeType}');
  }

  // ───────────────────────── Payments ─────────────────────────

  /// ✅ List payments for one invoice.
  ///
  /// IMPORTANT:
  /// Your backend may not implement this route yet. When it returns 404,
  /// we treat that as "payments not supported" and return [] so the UI keeps working.
  Future<List<ZohoInvoicePayment>> listPayments(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.zohoListInvoicePayments(invoiceId: id);

    // ✅ Accept 404 so Dio doesn't throw
    final res = await api.getUri(
      uri,
      options: Options(
        validateStatus: (code) {
          if (code == null) return false;
          if (code == 404) return true; // treat as supported "no route"
          return code >= 200 && code < 300;
        },
        extra: const {'silence404': true}, // optional: used by Patch 2 below
      ),
    );

    // 404 => backend route not implemented => "no payments feature" => []
    if (res.statusCode == 404) return const <ZohoInvoicePayment>[];

    final data = _asJsonMap(res.data);

    final raw =
        data['payments'] ??
        data['customerpayments'] ??
        data['payment_details'] ??
        data['items'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ZohoInvoicePayment.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return const <ZohoInvoicePayment>[];
  }

  Future<JsonMap> recordPayment(String invoiceId, PaymentDraft draft) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final amt = _safeAmount(draft.amount);
    if (amt <= 0) throw ArgumentError('amount must be > 0');

    final uri = routes.zohoCreateInvoicePayment(invoiceId: id);

    final body = <String, Object?>{
      'amount': amt,
      'date': _zohoDateFmt.format(_dateOnly(draft.date)),
      if (_cleanOrNull(draft.mode) != null)
        'payment_mode': _cleanOrNull(draft.mode),
      if (_cleanOrNull(draft.referenceNumber) != null)
        'reference_number': _cleanOrNull(draft.referenceNumber),
      if (_cleanOrNull(draft.description) != null)
        'description': _cleanOrNull(draft.description),
      if (_cleanOrNull(draft.accountId) != null)
        'account_id': _cleanOrNull(draft.accountId),
    };

    final res = await api.postUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<JsonMap> updatePayment(String paymentId, PaymentDraft draft) async {
    final id = paymentId.trim();
    if (id.isEmpty) throw ArgumentError('paymentId is empty');

    final uri = routes.zohoUpdatePayment(paymentId: id);

    final body = <String, Object?>{
      'amount': _safeAmount(draft.amount),
      'date': _zohoDateFmt.format(_dateOnly(draft.date)),
      if (_cleanOrNull(draft.mode) != null)
        'payment_mode': _cleanOrNull(draft.mode),
      if (_cleanOrNull(draft.referenceNumber) != null)
        'reference_number': _cleanOrNull(draft.referenceNumber),
      if (_cleanOrNull(draft.description) != null)
        'description': _cleanOrNull(draft.description),
      if (_cleanOrNull(draft.accountId) != null)
        'account_id': _cleanOrNull(draft.accountId),
    };

    final res = await api.putUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<void> deletePayment(String paymentId) async {
    final id = paymentId.trim();
    if (id.isEmpty) throw ArgumentError('paymentId is empty');

    final uri = routes.zohoDeletePayment(paymentId: id);
    await api.deleteUri(uri);
  }

  // ───────────────────────── Helpers ─────────────────────────

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static String? _cleanOrNull(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static num _safeAmount(num v) {
    if (v.isNaN || v.isInfinite) return 0;
    if (v < 0) return 0;
    return v;
  }

  static JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
