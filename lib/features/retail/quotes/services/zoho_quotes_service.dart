// lib/features/retail/quotes/services/zoho_quotes_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

  /// Lightweight model fetch (good for list/details).
  Future<ZohoQuote> get(String quoteId) async {
    final uri = routes.zohoGetQuote(quoteId);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['quote'] ?? data['estimate'] ?? data;
    if (raw is Map) {
      return ZohoQuote.fromJson(raw.cast<String, dynamic>());
    }
    throw StateError('Unexpected response shape: missing quote object');
  }

  /// Raw fetch (needed for editor hydration, includes line_items etc.)
  Future<JsonMap> getQuote(String quoteId) async {
    final uri = routes.zohoGetQuote(quoteId);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);

    final raw = data['quote'] ?? data['estimate'] ?? data;
    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();

    throw StateError('Unexpected response shape: missing quote object');
  }

  Future<JsonMap> createQuoteFromDraft(QuoteDraft draft) async {
    final body = _buildDraftPayload(draft, requireCustomer: true);

    final uri = routes.zohoCreateQuote();
    final res = await api.postUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<JsonMap> updateQuoteFromDraft(String quoteId, QuoteDraft draft) async {
    final body = _buildDraftPayload(draft, requireCustomer: false);

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

  JsonMap _buildDraftPayload(
    QuoteDraft draft, {
    required bool requireCustomer,
  }) {
    final customerId = (draft.contact?.contactId ?? '').trim();

    // ✅ Client-side hard stop (matches backend requirement)
    if (requireCustomer && customerId.isEmpty) {
      throw StateError('customer is required (missing contactId)');
    }

    if (draft.lines.isEmpty) {
      throw StateError('quote must have at least one line');
    }

    final reference = (draft.reference ?? '').trim();
    final notes = (draft.customerNotes ?? '').trim();

    return <String, Object?>{
      // ✅ FIX: backend expects customer_id
      if (customerId.isNotEmpty) 'customer_id': customerId,

      // Optional compatibility: keep sending contact_id too (harmless if backend ignores)
      // If you want strictness, delete the next line.
      if (customerId.isNotEmpty) 'contact_id': customerId,

      if (reference.isNotEmpty) 'reference_number': reference,

      // ✅ FIX: use notes (your hydrator/back-end comment says "notes")
      if (notes.isNotEmpty) 'notes': notes,

      'line_items': draft.lines
          .map((l) {
            final title = l.tile.tileTitle.trim();
            final desc = (l.tile.tileDesc ?? '').trim();

            // You’re currently using free-text line items:
            // put the “real” label in description (works well for PDF/preview).
            final label = title.isEmpty
                ? (desc.isEmpty ? 'Item' : desc)
                : title;

            return <String, Object?>{
              'name': 'Item',
              'description': label,
              'quantity': l.quantity,
              'rate': l.rate,

              // Keep your metadata if your backend wants it (logging/mapping)
              'di_canon_key': l.tile.canonKey,
              'di_group_key': l.tile.groupKey,
              if (l.tile.form != null) 'form': l.tile.form,
              if (l.tile.bestPackCount != null)
                'pack_count': l.tile.bestPackCount,
              if (l.tile.bestSupplier != null)
                'best_supplier': l.tile.bestSupplier,
            };
          })
          .toList(growable: false),
    };
  }

  JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
