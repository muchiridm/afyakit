// lib/features/retail/quotes/services/zoho_quotes_service.dart

import 'dart:typed_data';

import 'package:afyakit/features/retail/shared/models/zoho_email_draft.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import '../models/quote_draft.dart';
import '../models/zoho_quote.dart';

final zohoQuotesServiceProvider = FutureProvider<ZohoQuotesService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientFutureProvider.future);
  return ZohoQuotesService(api: api, routes: routes);
});

class ZohoQuotesService {
  ZohoQuotesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static final DateFormat _zohoDateFmt = DateFormat('yyyy-MM-dd');

  // ───────────────────────── List / Get ─────────────────────────

  Future<List<ZohoQuote>> list({
    int limit = 50,
    int page = 1,
    String? q,
    String? accountNumber,
  }) async {
    final qq = (q ?? '').trim();
    final acct = (accountNumber ?? '').trim();

    final uri = routes.zohoListQuotes(
      limit: limit,
      page: page,
      q: qq.isEmpty ? null : qq,
      accountNumber: acct.isEmpty ? null : acct,
    );

    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['quotes'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ZohoQuote.fromJson(m.cast<String, dynamic>()))
          .toList(growable: false);
    }

    return const <ZohoQuote>[];
  }

  /// Strict: 404 throws.
  Future<ZohoQuote> get(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final uri = routes.zohoGetQuote(id);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['quote'];
    if (raw is Map) return ZohoQuote.fromJson(raw.cast<String, dynamic>());

    throw StateError('Unexpected response: missing "quote"');
  }

  /// ✅ Soft: 404 returns null (deleted / not found).
  Future<ZohoQuote?> getOrNull(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) return null;

    final uri = routes.zohoGetQuote(id);

    try {
      final res = await api.getUri(uri);

      final data = _asJsonMap(res.data);
      final raw = data['quote'];
      if (raw is Map) return ZohoQuote.fromJson(raw.cast<String, dynamic>());

      throw StateError('Unexpected response: missing "quote"');
    } on DioException catch (e) {
      final code = e.response?.statusCode;
      if (code == 404) return null;
      rethrow;
    }
  }

  // ───────────────────────── Create / Update / Delete ─────────────────────────
  //
  // Backend contract:
  // - POST uses CreateQuoteInput (customer_id required, line_items required)
  // - PUT is full replace (UpdateQuoteInput): line_items required, customer_id optional
  // ──────────────────────────────────────────────────────────────────────────

  Future<ZohoQuote> createFromDraft(
    QuoteDraft draft, {
    DateTime? quoteDate,
    DateTime? expiryDate, // ✅ NEW
  }) async {
    final body = _buildDraftPayload(
      draft,
      requireCustomer: true,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final uri = routes.zohoCreateQuote();
    final res = await api.postUri(uri, data: body);

    final data = _asJsonMap(res.data);
    final raw = data['quote'];
    if (raw is Map) return ZohoQuote.fromJson(raw.cast<String, dynamic>());

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<ZohoQuote> updateFromDraft(
    String quoteId,
    QuoteDraft draft, {
    DateTime? quoteDate,
    DateTime? expiryDate, // ✅ NEW
  }) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final body = _buildDraftPayload(
      draft,
      requireCustomer: false,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final uri = routes.zohoUpdateQuote(id);
    final res = await api.putUri(uri, data: body);

    final data = _asJsonMap(res.data);
    final raw = data['quote'];
    if (raw is Map) return ZohoQuote.fromJson(raw.cast<String, dynamic>());

    throw StateError('Unexpected response: missing "quote"');
  }

  Future<void> delete(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final uri = routes.zohoDeleteQuote(id);
    await api.deleteUri(uri);
  }

  // ───────────────────────── PDF ─────────────────────────

  Future<Uint8List> getPdf(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final uri = routes.zohoQuotePdf(id);

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

  // ───────────────────────── Email / Mark sent ─────────────────────────

  Future<void> email(String quoteId, {ZohoEmailDraft? email}) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final uri = routes.zohoSendQuote(id);

    final payload = _pruneEmailJson(
      email?.toJson() ?? const <String, Object?>{},
    );
    await api.postUri(uri, data: payload.isEmpty ? null : payload);
  }

  Future<void> markSent(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final uri = routes.zohoMarkQuoteSent(id);
    await api.postUri(uri);
  }

  Future<void> emailAndMarkSent(String quoteId, {ZohoEmailDraft? email}) async {
    email!;
    await markSent(quoteId);
  }

  // ───────────────────────── Convert to Invoice ─────────────────────────

  Future<JsonMap> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    final uri = routes.zohoConvertQuoteToInvoice(id);

    final body = <String, Object?>{
      if (invoiceDate != null)
        'invoice_date': _zohoDateFmt.format(_dateOnly(invoiceDate)),
      if (dueDate != null) 'due_date': _zohoDateFmt.format(_dateOnly(dueDate)),
    };

    final res = await api.postUri(uri, data: body.isEmpty ? null : body);
    return _asJsonMap(res.data);
  }

  // ───────────────────────── Payload builder ─────────────────────────

  JsonMap _buildDraftPayload(
    QuoteDraft draft, {
    required bool requireCustomer,
    DateTime? quoteDate,
    DateTime? expiryDate, // ✅ NEW
  }) {
    final customerId = draft.customerIdResolved.trim();

    if (requireCustomer && customerId.isEmpty) {
      throw StateError('customer_id is required');
    }

    if (draft.lines.isEmpty) {
      throw StateError('quote must have at least one line');
    }

    final quoteDateStr = quoteDate == null
        ? null
        : _zohoDateFmt.format(_dateOnly(quoteDate));

    final expiryDateStr = expiryDate == null
        ? null
        : _zohoDateFmt.format(_dateOnly(expiryDate));

    return <String, Object?>{
      if (customerId.isNotEmpty) 'customer_id': customerId,

      // Zoho: estimate_date
      if (quoteDateStr != null) 'date': quoteDateStr,

      // Zoho: expiry_date
      if (expiryDateStr != null) 'expiry_date': expiryDateStr,

      if (asCleanStringOrNull(draft.reference) != null)
        'reference_number': asCleanStringOrNull(draft.reference),

      if (asCleanStringOrNull(draft.customerNotes) != null)
        'notes': asCleanStringOrNull(draft.customerNotes),

      // ✅ NEW: delivery address
      if (draft.deliveryAddress != null)
        'delivery_address': draft.deliveryAddress!.toJson(),

      'line_items': draft.lines
          .map((l) {
            final lineItemId = asCleanStringOrNull(l.lineItemId);
            final name = _safeLineName(l);
            final description = _safeLineDescription(l);

            return <String, Object?>{
              if (lineItemId != null) 'line_item_id': lineItemId,
              'name': name,
              if (description != null) 'description': description,
              'quantity': _safeQty(l.quantity),
              'rate': _safeRate(l.rate),
            };
          })
          .toList(growable: false),
    };
  }

  // ───────────────────────── Tiny utils ─────────────────────────

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

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

    out.removeWhere((k, v) => v is String && v.trim().isEmpty);

    return out;
  }

  static String? asCleanStringOrNull(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static int _safeQty(int q) => q < 1 ? 1 : (q > 9999 ? 9999 : q);

  static num _safeRate(num r) {
    if (r.isNaN || r.isInfinite) return 0;
    if (r < 0) return 0;
    return r;
  }

  static String _safeLineName(QuoteLineDraft line) {
    final d = (line.description ?? '').trim();
    if (d.isNotEmpty) return _truncate(d, 120);

    final title = line.tile.tileTitle.trim();
    if (title.isNotEmpty) return _truncate(title, 120);

    final fallback = (line.tile.tileDesc ?? '').trim();
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

  static JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
