import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../models/invoice_draft.dart';
import '../models/zoho_invoice.dart';

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
    final uri = routes.zohoGetInvoice(invoiceId);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['invoice'] ?? data;

    if (raw is Map<String, dynamic>) return raw;
    if (raw is Map) return raw.cast<String, dynamic>();

    throw StateError('Unexpected response shape: missing invoice object');
  }

  Future<JsonMap> createInvoiceFromDraft(
    InvoiceDraft draft, {
    DateTime? invoiceDate,
  }) async {
    final body = _buildDraftPayload(
      draft,
      requireCustomer: true,
      invoiceDate: invoiceDate,
      includeLineItemIds: false, // ✅ create never needs line ids
    );

    final uri = routes.zohoCreateInvoice();
    final res = await api.postUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<String?> createInvoiceIdFromDraft(
    InvoiceDraft draft, {
    DateTime? invoiceDate,
  }) async {
    final res = await createInvoiceFromDraft(draft, invoiceDate: invoiceDate);
    final raw = res['invoice'] ?? res;
    if (raw is Map) {
      final m = raw.cast<String, dynamic>();
      final id = (m['invoice_id'] ?? m['id'])?.toString().trim();
      return (id == null || id.isEmpty) ? null : id;
    }
    return null;
  }

  Future<JsonMap> updateInvoiceFromDraft(
    String invoiceId,
    InvoiceDraft draft, {
    DateTime? invoiceDate,
  }) async {
    final body = _buildDraftPayload(
      draft,
      requireCustomer: false,
      invoiceDate: invoiceDate,
      includeLineItemIds: true, // ✅ critical for edit/update
    );

    final uri = routes.zohoUpdateInvoice(invoiceId);
    final res = await api.putUri(uri, data: body);
    return _asJsonMap(res.data);
  }

  Future<JsonMap> updateInvoice(String invoiceId, JsonMap patch) async {
    final uri = routes.zohoUpdateInvoice(invoiceId);
    final res = await api.putUri(uri, data: patch);
    return _asJsonMap(res.data);
  }

  Future<void> delete(String invoiceId) async {
    final uri = routes.zohoDeleteInvoice(invoiceId);
    await api.deleteUri(uri);
  }

  // ───────────────────────── Payload builder ─────────────────────────

  JsonMap _buildDraftPayload(
    InvoiceDraft draft, {
    required bool requireCustomer,
    required bool includeLineItemIds,
    DateTime? invoiceDate,
  }) {
    final customerId = (draft.contactId ?? draft.contact?.contactId ?? '')
        .trim();

    if (requireCustomer && customerId.isEmpty) {
      throw StateError('customer is required (missing contactId)');
    }

    if (draft.lines.isEmpty) {
      throw StateError('invoice must have at least one line');
    }

    final reference = _cleanOrNull(draft.reference);
    final notes = _cleanOrNull(draft.customerNotes);

    final dateStr = invoiceDate == null
        ? null
        : _zohoDateFmt.format(invoiceDate);
    final dueStr = draft.dueDate == null
        ? null
        : _zohoDateFmt.format(draft.dueDate!);

    return <String, Object?>{
      if (customerId.isNotEmpty) 'customer_id': customerId,
      if (dateStr != null) 'date': dateStr,
      if (dueStr != null) 'due_date': dueStr,
      if (reference != null) 'reference_number': reference,
      if (notes != null) 'notes': notes,

      'line_items': draft.lines
          .map((InvoiceLineDraft l) {
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

  static String _safeLineName(InvoiceLineDraft line) {
    final tile = line.tile;

    final d = (line.description ?? '').trim();
    if (d.isNotEmpty) return _truncate(d, 120);

    final title = (tile.tileTitle).trim();
    if (title.isNotEmpty) return _truncate(title, 120);

    final fallback = (tile.tileDesc ?? '').trim();
    return _truncate(fallback.isNotEmpty ? fallback : 'Item', 120);
  }

  static String? _safeLineDescription(InvoiceLineDraft line) {
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
