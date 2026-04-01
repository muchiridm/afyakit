// lib/features/retail/quotes/controllers/quote_engine.dart

import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';

import 'package:afyakit/features/retail/quotes/models/di_sales_tile.dart';
import 'package:afyakit/features/retail/quotes/models/quote_draft.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';

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

  // ───────────────────────── Date helpers ─────────────────────────

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
    final quoteDate = normalizeDate(q.date);
    final expiryDate = normalizeDate(q.expiryDate);

    final draft = QuoteDraft.fromZohoQuote(q);

    return QuoteMetaState(
      contact: draft.contact,
      reference: (draft.reference ?? '').trim().isEmpty
          ? null
          : draft.reference!.trim(),
      customerNotes: (draft.customerNotes ?? '').trim().isEmpty
          ? null
          : draft.customerNotes!.trim(),
      quoteDate: quoteDate,
      expiryDate: expiryDate,
      deliveryAddress: q.deliveryAddress,
    );
  }

  // ───────────────────────── Validation ─────────────────────────

  String? validateForSubmitV2({
    required QuoteMetaState meta,
    required bool requirePrices,
    required bool isEditing,
  }) {
    if (_lines.lines.isEmpty) {
      return isEditing ? 'Quote has no items' : 'Add at least one item';
    }

    if (!isEditing && meta.customerIdResolved.isEmpty) {
      return 'Please pick a customer';
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
      deliveryAddress: meta.deliveryAddress,
      lines: lineDrafts,
    );
  }

  List<QuoteLineDraft> _buildLineDrafts({required bool requirePrices}) {
    return _lines.lines
        .map((l) {
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

            final tile = _toDiSalesTileFromCatalogLine(
              l,
              name: name,
              desc: desc,
            );

            return QuoteLineDraft(
              tile: tile,
              quantity: qty,
              rate: safeRate,
              description: name,
              lineItemId: null,
            );
          }

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
            description: name,
            lineItemId: lineItemId,
          );
        })
        .toList(growable: false);
  }

  // ───────────────────────── Remote ops ─────────────────────────

  Future<ZohoQuote> create(
    QuoteDraft payload, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async => (await _svc).createFromDraft(
    payload,
    quoteDate: quoteDate,
    expiryDate: expiryDate,
  );

  Future<ZohoQuote> update(
    String quoteId,
    QuoteDraft payload, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async => (await _svc).updateFromDraft(
    quoteId,
    payload,
    quoteDate: quoteDate,
    expiryDate: expiryDate,
  );

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
