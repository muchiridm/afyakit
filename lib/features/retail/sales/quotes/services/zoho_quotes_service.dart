// lib/features/retail/sales/quotes/services/zoho_quotes_service.dart

import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../models/quote_draft.dart';
import '../models/zoho_quote.dart';

typedef JsonMap = Map<String, dynamic>;

final zohoQuotesServiceProvider = FutureProvider<ZohoQuotesService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientProvider.future);
  return ZohoQuotesService(api: api, routes: routes);
});

class ZohoQuotesService {
  ZohoQuotesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static final DateFormat _zohoDateFmt = DateFormat('yyyy-MM-dd');

  // ───────────────────────── List / Get ─────────────────────────

  Future<List<ZohoQuote>> list({int limit = 50, int page = 1}) async {
    final uri = routes.zohoListQuotes(limit: limit, page: page);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['quotes'] ?? data['estimates'] ?? data['items'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ZohoQuote.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return const <ZohoQuote>[];
  }

  Future<ZohoQuote> get(String quoteId) async {
    final raw = await getQuote(quoteId);
    return ZohoQuote.fromJson(raw);
  }

  Future<JsonMap> getQuote(String quoteId) async {
    final uri = routes.zohoGetQuote(quoteId);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['quote'] ?? data['estimate'] ?? data;

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();

    throw StateError('Unexpected response shape: missing quote object');
  }

  // ───────────────────────── Create / Update / Delete ─────────────────────────

  Future<JsonMap> createQuoteFromDraft(
    QuoteDraft draft, {
    DateTime? quoteDate,
  }) async {
    final body = _buildDraftPayload(
      draft,
      requireCustomer: true,
      quoteDate: quoteDate,
      includeLineItemIds: false,
    );

    final uri = routes.zohoCreateQuote();
    final res = await api.postUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<String?> createQuoteIdFromDraft(
    QuoteDraft draft, {
    DateTime? quoteDate,
  }) async {
    final res = await createQuoteFromDraft(draft, quoteDate: quoteDate);
    final raw = res['quote'] ?? res['estimate'] ?? res;

    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final id = (m['quote_id'] ?? m['estimate_id'] ?? m['id'])
          ?.toString()
          .trim();
      return (id == null || id.isEmpty) ? null : id;
    }

    return null;
  }

  Future<JsonMap> updateQuoteFromDraft(
    String quoteId,
    QuoteDraft draft, {
    DateTime? quoteDate,
  }) async {
    final body = _buildDraftPayload(
      draft,
      requireCustomer: false,
      quoteDate: quoteDate,
      includeLineItemIds: true,
    );

    final uri = routes.zohoUpdateQuote(quoteId);
    final res = await api.putUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<JsonMap> updateQuote(String quoteId, JsonMap patch) async {
    final uri = routes.zohoUpdateQuote(quoteId);
    final res = await api.putUri(uri, data: patch);
    return _asJsonMap(res.data);
  }

  Future<void> delete(String quoteId) async {
    final uri = routes.zohoDeleteQuote(quoteId);
    await api.deleteUri(uri);
  }

  // ───────────────────────── PDF ─────────────────────────

  /// Returns raw PDF bytes for inline rendering / download.
  ///
  /// Requires AfyaKitClient.getUri to accept dio.Options (see client patch below).
  Future<Uint8List> getPdf(String quoteId) async {
    final uri = routes.zohoQuotePdf(quoteId);

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

  // ───────────────────────── Send / Mark Sent ─────────────────────────

  Future<void> sendQuote(String quoteId) async {
    final uri = routes.zohoSendQuote(quoteId);
    await api.postUri(uri);
  }

  Future<void> markQuoteSent(String quoteId) async {
    final uri = routes.zohoMarkQuoteSent(quoteId);
    await api.postUri(uri);
  }

  Future<void> sendAndMarkSent(String quoteId) async {
    await sendQuote(quoteId);
    await markQuoteSent(quoteId);
  }

  // ───────────────────────── Convert to Invoice ─────────────────────────

  Future<JsonMap> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async {
    final uri = routes.zohoConvertQuoteToInvoice(quoteId);

    final body = <String, Object?>{
      if (invoiceDate != null) 'invoice_date': _zohoDateFmt.format(invoiceDate),
      if (dueDate != null) 'due_date': _zohoDateFmt.format(dueDate),
    };

    final res = await api.postUri(uri, data: body.isEmpty ? null : body);
    return _asJsonMap(res.data);
  }

  // ───────────────────────── Payload builder ─────────────────────────

  JsonMap _buildDraftPayload(
    QuoteDraft draft, {
    required bool requireCustomer,
    required bool includeLineItemIds,
    DateTime? quoteDate,
  }) {
    final customerId = (draft.contactId ?? draft.contact?.contactId ?? '')
        .trim();

    if (requireCustomer && customerId.isEmpty) {
      throw StateError('customer is required (missing contactId)');
    }

    if (draft.lines.isEmpty) {
      throw StateError('quote must have at least one line');
    }

    final reference = _cleanOrNull(draft.reference);
    final notes = _cleanOrNull(draft.customerNotes);
    final dateStr = quoteDate == null ? null : _zohoDateFmt.format(quoteDate);

    return <String, Object?>{
      if (customerId.isNotEmpty) 'customer_id': customerId,
      if (dateStr != null) 'date': dateStr,
      if (reference != null) 'reference_number': reference,
      if (notes != null) 'notes': notes,
      'line_items': draft.lines
          .map((QuoteLineDraft l) {
            final qty = _safeQty(l.quantity);
            final rate = _safeRate(l.rate);

            final name = _safeLineName(l);
            final description = _safeLineDescription(l);

            final lineItemId = (l.lineItemId ?? '').trim();

            return <String, Object?>{
              if (includeLineItemIds && lineItemId.isNotEmpty)
                'line_item_id': lineItemId,
              'name': name,
              if (description != null) 'description': description,
              'quantity': qty,
              'rate': rate,
            };
          })
          .toList(growable: false),
    };
  }

  static String? _cleanOrNull(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static int _safeQty(int q) {
    if (q < 1) return 1;
    if (q > 9999) return 9999;
    return q;
  }

  static num _safeRate(num r) {
    if (r.isNaN || r.isInfinite) return 0;
    if (r < 0) return 0;
    return r;
  }

  static String _safeLineName(QuoteLineDraft line) {
    final tile = line.tile;

    final d = (line.description ?? '').trim();
    if (d.isNotEmpty) return _truncate(d, 120);

    final title = tile.tileTitle.trim();
    if (title.isNotEmpty) return _truncate(title, 120);

    final fallback = (tile.tileDesc ?? '').trim();
    return _truncate(fallback.isNotEmpty ? fallback : 'Item', 120);
  }

  static String? _safeLineDescription(QuoteLineDraft line) {
    final desc = (line.tile.tileDesc ?? '').trim();
    if (desc.isEmpty) return null;
    return _truncate(desc, 500);
  }

  static String _truncate(String v, int max) {
    final s = v.trim();
    if (s.length <= max) return s;
    return s.substring(0, max - 1).trimRight();
  }

  JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
