// lib/features/retail/sales/invoices/services/zoho_invoices_service.dart

import 'dart:typed_data';

import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import '../../shared/models/zoho_invoice.dart';

final zohoInvoicesServiceProvider = FutureProvider<ZohoInvoicesService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientFutureProvider.future);
  return ZohoInvoicesService(api: api, routes: routes);
});

class ZohoInvoicesService {
  ZohoInvoicesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  // ───────────────────────── Read ─────────────────────────

  Future<List<ZohoInvoice>> list({
    int limit = 50,
    int page = 1,
    String? q,
    String? accountNumber,
  }) async {
    final qq = (q ?? '').trim();
    final acct = (accountNumber ?? '').trim();

    final uri = routes.retailListInvoices(
      limit: limit,
      page: page,
      q: qq.isEmpty ? null : qq,
      accountNumber: acct.isEmpty ? null : acct,
    );

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
    final raw = await getInvoiceJson(invoiceId);
    return ZohoInvoice.fromJson(raw);
  }

  Future<JsonMap> getInvoiceJson(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.retailGetInvoice(id);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['invoice'] ?? data;

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();

    throw StateError('Unexpected response shape: missing invoice object');
  }

  /// Backend contract is PATCH /invoices/:invoiceId (partial update).
  /// Keep this as a thin transport call.
  Future<JsonMap> patchInvoice(String invoiceId, JsonMap patch) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.retailUpdateInvoice(id);
    final res = await api.patchUri(uri, data: patch);

    return _asJsonMap(res.data);
  }

  // ───────────────────────── Email / Mark Sent ─────────────────────────

  Future<void> sendInvoice(
    String invoiceId, {
    required ZohoEmailDraft email,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.retailSendInvoice(id);

    final payload = _pruneEmailJson(email.toJson());
    await api.postUri(uri, data: payload.isEmpty ? null : payload);
  }

  Future<void> markSent(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.retailMarkInvoiceSent(id);
    await api.postUri(uri);
  }

  Future<void> sendAndMarkSent(
    String invoiceId, {
    required ZohoEmailDraft email,
  }) async {
    await sendInvoice(invoiceId, email: email);
    await markSent(invoiceId);
  }

  // ───────────────────────── PDF ─────────────────────────

  Future<Uint8List> getPdf(String invoiceId) async {
    final id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final uri = routes.retailInvoicePdf(id);

    final res = await api.getUri(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const {'Accept': 'application/pdf'},
      ),
    );

    final data = res.data;
    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);

    throw StateError('Expected PDF bytes but got ${data.runtimeType}');
  }

  // ───────────────────────── Helpers ─────────────────────────

  static Map<String, Object?> _pruneEmailJson(Map<String, Object?> input) {
    final out = <String, Object?>{...input};

    void dropEmptyList(String key) {
      final v = out[key];
      if (v is List && v.isEmpty) out.remove(key);
    }

    dropEmptyList('to_mail_ids');
    dropEmptyList('cc_mail_ids');
    dropEmptyList('bcc_mail_ids');
    dropEmptyList('contact_person_ids');

    out.removeWhere((_, v) => v is String && v.trim().isEmpty);

    for (final k in const [
      'to_mail_ids',
      'cc_mail_ids',
      'bcc_mail_ids',
      'contact_person_ids',
    ]) {
      final v = out[k];
      if (v is List) {
        final cleaned = v
            .map((e) => e is String ? e.trim() : e)
            .where((e) => e != null && (e is! String || e.isNotEmpty))
            .toList(growable: false);
        if (cleaned.isEmpty) {
          out.remove(k);
        } else {
          out[k] = cleaned;
        }
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
