// lib/features/retail/quotes/controllers/quote_engine.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_state.dart';
import 'package:afyakit/features/retail/quotes/models/di_sales_tile.dart';
import 'package:afyakit/features/retail/quotes/models/quote_draft.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';

class QuoteEngine {
  QuoteEngine(this.ref);

  final Ref ref;

  QuoteLinesController get _linesCtl =>
      ref.read(quoteLinesControllerProvider.notifier);

  QuoteLinesState get _lines => ref.read(quoteLinesControllerProvider);

  Future<ZohoQuotesService> get _svc async =>
      ref.read(zohoQuotesServiceProvider.future);

  // ───────────────────────── Session orchestration ─────────────────────────

  bool isEditingId(String? id) => (id ?? '').trim().isNotEmpty;

  bool shouldClearLinesOnSwitch({
    required String? prevEditingId,
    required String? prevLoadedId,
    required String nextEditingId,
  }) {
    final hadEditSession =
        (prevEditingId ?? '').trim().isNotEmpty ||
        (prevLoadedId ?? '').trim().isNotEmpty;

    final wantEdit = nextEditingId.trim().isNotEmpty;

    if (!wantEdit && hadEditSession) return true;

    if (wantEdit &&
        ((prevEditingId ?? '').trim() != nextEditingId.trim() ||
            (prevLoadedId ?? '').trim() != nextEditingId.trim())) {
      return true;
    }

    return false;
  }

  // ───────────────────────── Draft patching (legacy helper) ─────────────────────────

  QuoteDraft patchDraftMeta(
    QuoteDraft cur, {
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
  }) {
    var next = cur;

    if (contact != null) {
      final customerId = contact.contactId.trim();
      final customerName = contact.title.trim();

      next = next.copyWith(
        contact: contact,
        contactId: customerId.isEmpty ? null : customerId,
        contactName: customerName.isEmpty ? null : customerName,
      );
    }

    if (reference != null) {
      final t = reference.trim();
      next = next.copyWith(reference: t.isEmpty ? null : t);
    }

    if (customerNotes != null) {
      final t = customerNotes.trim();
      next = next.copyWith(customerNotes: t.isEmpty ? null : t);
    }

    return next;
  }

  DateTime? normalizeDate(DateTime? d) {
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }

  // ───────────────────────── Load edit ─────────────────────────

  Future<ZohoQuote> loadQuote(String quoteId) async {
    final id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');
    return (await _svc).get(id);
  }

  void setLinesFromZoho(ZohoQuote q) {
    // Current approach: hydrate as ManualQuoteLine so we preserve Zoho line_item_id.
    final lines = q.lineItems
        .map((li) {
          final qty = li.quantity.round().clamp(1, 9999);
          final rate = (li.rate.isNaN || li.rate.isInfinite || li.rate < 0)
              ? 0
              : li.rate;

          final name = li.name.trim().isEmpty ? 'Item' : li.name.trim();
          final desc = (li.description ?? '').trim().isEmpty
              ? null
              : li.description!.trim();

          final zohoLineId = (li.lineItemId ?? '').trim();
          final manualId = zohoLineId.isNotEmpty
              ? 'z_$zohoLineId'
              : 'm_${DateTime.now().microsecondsSinceEpoch}';

          return ManualQuoteLine(
            manualId: manualId,
            name: name,
            description: desc,
            rate: rate,
            qty: qty,
            zohoLineItemId: zohoLineId.isEmpty ? null : zohoLineId,
          );
        })
        .toList(growable: false);

    _linesCtl.replaceAll(lines);
  }

  QuoteMetaState metaFromZoho(ZohoQuote q) {
    final draft = QuoteDraft.fromZohoQuote(q);

    final d = q.date;
    final quoteDate = d == null ? null : DateTime(d.year, d.month, d.day);

    return QuoteMetaState(
      contact: draft.contact,
      reference: (draft.reference ?? '').trim().isEmpty
          ? null
          : draft.reference!.trim(),
      customerNotes: (draft.customerNotes ?? '').trim().isEmpty
          ? null
          : draft.customerNotes!.trim(),
      quoteDate: quoteDate,
    );
  }

  DateTime? quoteDateFromZoho(ZohoQuote q) => q.date == null
      ? null
      : DateTime(q.date!.year, q.date!.month, q.date!.day);

  // ───────────────────────── Validation ─────────────────────────

  String? validateForSubmit({
    required QuoteState state,
    required bool requirePrices,
  }) {
    if (_lines.lines.isEmpty) {
      return state.isEditing ? 'Quote has no items' : 'Add at least one item';
    }

    if (!state.isEditing) {
      return null;
    }

    final unnamedManual = _lines.lines.whereType<ManualQuoteLine>().where((l) {
      return l.name.trim().isEmpty;
    }).toList();
    if (unnamedManual.isNotEmpty) {
      return 'Some items are missing a name. Please edit them.';
    }

    return null;
  }

  String? validateForSubmitV2({
    required QuoteMetaState meta,
    required bool requirePrices,
    required bool isEditing,
  }) {
    if (_lines.lines.isEmpty) {
      return isEditing ? 'Quote has no items' : 'Add at least one item';
    }

    if (!isEditing) {
      if (meta.customerIdResolved.isEmpty) return 'Please pick a customer';
    }

    final unnamedManual = _lines.lines.whereType<ManualQuoteLine>().where((l) {
      return l.name.trim().isEmpty;
    }).toList();
    if (unnamedManual.isNotEmpty) {
      return 'Some items are missing a name. Please edit them.';
    }

    return null;
  }

  int missingPriceLineCount() => _lines.missingPriceLineCount;

  // ───────────────────────── Payload build ─────────────────────────

  QuoteDraft buildPayloadDraftFromState(QuoteState state) {
    final lineDrafts = _buildLineDrafts(requirePrices: true);
    return const QuoteDraft().copyWith(lines: lineDrafts);
  }

  QuoteDraft buildPayloadDraftFromMeta({
    required QuoteMetaState meta,
    required bool requirePrices,
  }) {
    final lineDrafts = _buildLineDrafts(requirePrices: requirePrices);

    final contact = meta.contact;
    final customerId = (contact?.contactId ?? '').trim();
    final customerName = (contact?.title ?? '').trim();

    return QuoteDraft(
      contact: contact,
      contactId: customerId.isEmpty ? null : customerId,
      contactName: customerName.isEmpty ? null : customerName,
      reference: (meta.reference ?? '').trim().isEmpty
          ? null
          : meta.reference!.trim(),
      customerNotes: (meta.customerNotes ?? '').trim().isNotEmpty
          ? meta.customerNotes!.trim()
          : null,
      lines: lineDrafts,
    );
  }

  /// ✅ FIXED:
  /// Must match ZohoQuotesService mapping:
  /// - Zoho "name" comes from QuoteLineDraft.description (preferred), then tileTitle.
  /// - Zoho "description" comes from tile.tileDesc.
  /// - rate/quantity from draft.rate/draft.quantity.
  List<QuoteLineDraft> _buildLineDrafts({required bool requirePrices}) {
    return _lines.lines
        .map((l) {
          // ───────────────────────── Catalog lines ─────────────────────────
          if (l is CatalogQuoteLine) {
            final qty = (l.qty < 1 ? 1 : l.qty).clamp(1, 9999);

            final name = l.effectiveName.trim().isEmpty
                ? 'Item'
                : l.effectiveName.trim();

            final desc = (l.effectiveDescription ?? '').trim().isEmpty
                ? null
                : l.effectiveDescription!.trim();

            final num rate = requirePrices ? l.effectiveRate : 0;
            final safeRate = (rate.isNaN || rate.isInfinite || rate < 0)
                ? 0
                : rate;

            // Build a tile that reflects edits:
            // - tileTitle is fallback name
            // - tileDesc becomes Zoho description
            // - bestSellPrice reflects edited rate (useful elsewhere)
            final tile = _toDiSalesTileFromCatalogLine(
              l,
              name: name,
              desc: desc,
            );

            return QuoteLineDraft(
              tile: tile,
              quantity: qty,
              rate: safeRate,

              // ✅ Critical: this is what ZohoQuotesService uses as "name"
              description: name,

              // Catalog lines currently don't preserve Zoho line_item_id
              lineItemId: null,
            );
          }

          // ───────────────────────── Manual lines ─────────────────────────
          final m = l as ManualQuoteLine;

          final qty = (m.qty < 1 ? 1 : m.qty).clamp(1, 9999);

          final num rate = requirePrices ? m.rate : 0;
          final safeRate = (rate.isNaN || rate.isInfinite || rate < 0)
              ? 0
              : rate;

          final name = m.name.trim().isEmpty ? 'Item' : m.name.trim();
          final desc = (m.description ?? '').trim().isEmpty
              ? null
              : m.description!.trim();

          // This tile feeds Zoho description via tileDesc
          final tile = DiSalesTile.fallbackFromName(
            name: name,
            description: desc,
            canonKey: m.manualId,
            groupKey: m.manualId,
          );

          final lineItemId = (m.zohoLineItemId ?? '').trim().isEmpty
              ? null
              : m.zohoLineItemId!.trim();

          return QuoteLineDraft(
            tile: tile,
            quantity: qty,
            rate: safeRate,

            // ✅ Zoho name (service prefers this over tileTitle)
            description: name,

            // ✅ Preserve Zoho identity for in-place updates
            lineItemId: lineItemId,
          );
        })
        .toList(growable: false);
  }

  // ───────────────────────── Remote ops ─────────────────────────

  Future<ZohoQuote> create(QuoteDraft payload, {DateTime? quoteDate}) async =>
      (await _svc).createFromDraft(payload, quoteDate: quoteDate);

  Future<ZohoQuote> update(
    String quoteId,
    QuoteDraft payload, {
    DateTime? quoteDate,
  }) async =>
      (await _svc).updateFromDraft(quoteId, payload, quoteDate: quoteDate);

  Future<void> delete(String quoteId) async => (await _svc).delete(quoteId);

  Future<Uint8List> getPdf(String quoteId) async =>
      (await _svc).getPdf(quoteId);

  Future<void> email(String quoteId) async => (await _svc).email(quoteId);

  Future<void> markSent(String quoteId) async => (await _svc).markSent(quoteId);

  Future<void> emailAndMarkSent(String quoteId) async =>
      (await _svc).emailAndMarkSent(quoteId);

  Future<Map<String, dynamic>> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async => (await _svc).convertToInvoice(
    quoteId,
    invoiceDate: invoiceDate,
    dueDate: dueDate,
  );

  // ───────────────────────── Helpers ─────────────────────────

  /// ✅ NEW: builds a DiSalesTile that reflects user overrides.
  /// IMPORTANT:
  /// - Zoho description comes from tileDesc.
  /// - Zoho name comes from QuoteLineDraft.description, but tileTitle is still a good fallback.
  static DiSalesTile _toDiSalesTileFromCatalogLine(
    CatalogQuoteLine l, {
    required String name,
    required String? desc,
  }) {
    final t = l.tile;
    final key = t.id;

    return DiSalesTile(
      canonKey: key,
      groupKey: key,
      tileTitle: name,
      tileDesc: (desc ?? '').trim().isEmpty ? null : desc!.trim(),
      form: t.form.trim().isEmpty ? null : t.form,
      bestPackCount: t.bestPackCount,
      offerCount: t.offerCount ?? 0,
      bestSellPrice: l.effectiveRate,
      bestSupplier: (t.bestSupplier ?? '').trim().isNotEmpty
          ? t.bestSupplier!.trim()
          : null,
      priceRequestRequired: null,
    );
  }
}
