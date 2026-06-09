// lib/features/retail/invoices/services/zoho_invoices_service.dart

import 'dart:typed_data';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/retail/invoices/models/zoho_invoice.dart';
import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final zohoInvoicesServiceProvider = FutureProvider<ZohoInvoicesService>((
  Ref ref,
) async {
  final String tenantId = ref.watch(tenantIdProvider);
  final AfyaKitRoutes routes = AfyaKitRoutes(tenantId);
  final AfyaKitClient api = await ref.watch(afyakitClientFutureProvider.future);

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
    String? customerId,

    String? patientId,
    String? patientNo,
    String? claimPackId,
    String? membershipId,
    String? prescriptionId,
  }) async {
    final String qq = (q ?? '').trim();
    final String acct = (accountNumber ?? '').trim();
    final String cid = (customerId ?? '').trim();

    final String pid = (patientId ?? '').trim();
    final String pno = (patientNo ?? '').trim();
    final String claimId = (claimPackId ?? '').trim();
    final String mid = (membershipId ?? '').trim();
    final String rxid = (prescriptionId ?? '').trim();

    final Uri uri = routes.retailListInvoices(
      limit: limit,
      page: page,
      q: qq.isEmpty ? null : qq,
      accountNumber: acct.isEmpty ? null : acct,
      customerId: cid.isEmpty ? null : cid,
      patientId: pid.isEmpty ? null : pid,
      patientNo: pno.isEmpty ? null : pno,
      claimPackId: claimId.isEmpty ? null : claimId,
      membershipId: mid.isEmpty ? null : mid,
      prescriptionId: rxid.isEmpty ? null : rxid,
    );

    final Response<dynamic> res = await api.getUri(uri);

    final JsonMap data = _asJsonMap(res.data);
    final Object? raw = data['invoices'] ?? data['items'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((Map<dynamic, dynamic> m) {
            return ZohoInvoice.fromJson(m.cast<String, dynamic>());
          })
          .toList(growable: false);
    }

    return const <ZohoInvoice>[];
  }

  Future<ZohoInvoice> get(String invoiceId) async {
    final JsonMap raw = await getInvoiceJson(invoiceId);
    return ZohoInvoice.fromJson(raw);
  }

  Future<JsonMap> getInvoiceJson(String invoiceId) async {
    final String id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final Uri uri = routes.retailGetInvoice(id);
    final Response<dynamic> res = await api.getUri(uri);

    final JsonMap data = _asJsonMap(res.data);
    final Object? raw = data['invoice'] ?? data;

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();

    throw StateError('Unexpected response shape: missing invoice object');
  }

  /// Backend contract is PATCH /invoices/:invoiceId.
  Future<JsonMap> patchInvoice(String invoiceId, JsonMap patch) async {
    final String id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final Uri uri = routes.retailUpdateInvoice(id);
    final Response<dynamic> res = await api.patchUri(uri, data: patch);

    return _asJsonMap(res.data);
  }

  // ───────────────────────── Email / Mark Sent ─────────────────────────

  Future<void> sendInvoice(
    String invoiceId, {
    required ZohoEmailDraft email,
  }) async {
    final String id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final Uri uri = routes.retailSendInvoice(id);

    final Map<String, Object?> payload = _pruneEmailJson(email.toJson());
    await api.postUri(uri, data: payload.isEmpty ? null : payload);
  }

  Future<void> markSent(String invoiceId) async {
    final String id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final Uri uri = routes.retailMarkInvoiceSent(id);
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
    final String id = invoiceId.trim();
    if (id.isEmpty) throw ArgumentError('invoiceId is empty');

    final Uri uri = routes.retailInvoicePdf(id);

    final Response<dynamic> res = await api.getUri(
      uri,
      options: Options(
        responseType: ResponseType.bytes,
        headers: const <String, String>{'Accept': 'application/pdf'},
      ),
    );

    final Object? data = res.data;

    if (data is Uint8List) return data;
    if (data is List<int>) return Uint8List.fromList(data);

    throw StateError('Expected PDF bytes but got ${data.runtimeType}');
  }

  // ───────────────────────── Helpers ─────────────────────────

  static Map<String, Object?> _pruneEmailJson(Map<String, Object?> input) {
    final Map<String, Object?> out = <String, Object?>{...input};

    void dropEmptyList(String key) {
      final Object? v = out[key];
      if (v is List && v.isEmpty) out.remove(key);
    }

    dropEmptyList('to_mail_ids');
    dropEmptyList('cc_mail_ids');
    dropEmptyList('bcc_mail_ids');
    dropEmptyList('contact_person_ids');

    out.removeWhere((_, Object? v) => v is String && v.trim().isEmpty);

    for (final String key in const <String>[
      'to_mail_ids',
      'cc_mail_ids',
      'bcc_mail_ids',
      'contact_person_ids',
    ]) {
      final Object? value = out[key];

      if (value is List) {
        final List<Object> cleaned = value
            .map((Object? e) => e is String ? e.trim() : e)
            .whereType<Object>()
            .where((Object e) => e is! String || e.isNotEmpty)
            .toList(growable: false);

        if (cleaned.isEmpty) {
          out.remove(key);
        } else {
          out[key] = cleaned;
        }
      }
    }

    return out;
  }

  static JsonMap _asJsonMap(Object? value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) return value.cast<String, dynamic>();

    throw StateError('Expected JSON object but got ${value.runtimeType}');
  }
}
