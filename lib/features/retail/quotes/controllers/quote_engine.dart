// lib/features/retail/quotes/controllers/quote_engine.dart

import 'dart:typed_data';

import 'package:afyakit/features/retail/catalog/models/catalog_models.dart';
import 'package:afyakit/features/retail/catalog/models/di_sales_tile.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/models/quote_draft.dart';
import 'package:afyakit/features/retail/quotes/models/quote_line_draft.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class QuoteEngine {
  QuoteEngine(this.ref);

  final Ref ref;

  QuoteLinesController get _linesCtl =>
      ref.read(quoteLinesControllerProvider.notifier);

  QuoteLinesState get _lines => ref.read(quoteLinesControllerProvider);

  Future<ZohoQuotesService> get _svc async {
    return ref.read(zohoQuotesServiceProvider.future);
  }

  // ───────────────────────── Session helpers ─────────────────────────

  bool isEditingId(String? id) => _cleanNullable(id) != null;

  bool shouldClearLinesOnSwitch({
    required String? prevEditingId,
    required String? prevLoadedId,
    required String nextEditingId,
  }) {
    final String prevEdit = _cleanNullable(prevEditingId) ?? '';
    final String prevLoaded = _cleanNullable(prevLoadedId) ?? '';
    final String next = nextEditingId.trim();

    final bool hadEditSession = prevEdit.isNotEmpty || prevLoaded.isNotEmpty;

    if (next.isEmpty && hadEditSession) return true;

    return next.isNotEmpty && (prevEdit != next || prevLoaded != next);
  }

  DateTime? normalizeDate(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  // ───────────────────────── Quote loading / hydration ─────────────────────────

  Future<ZohoQuote> loadQuote(String quoteId) async {
    final String id = quoteId.trim();
    if (id.isEmpty) throw StateError('quoteId is empty');

    return (await _svc).get(id);
  }

  void setLinesFromZoho(ZohoQuote quote) {
    final List<ManualQuoteLine> lines = quote.lineItems
        .map(_manualLineFromZohoLine)
        .toList(growable: false);

    _linesCtl.replaceAll(lines);
  }

  ManualQuoteLine _manualLineFromZohoLine(ZohoQuoteLineItem line) {
    final String zohoLineId = _cleanNullable(line.lineItemId) ?? '';

    return ManualQuoteLine(
      manualId: zohoLineId.isNotEmpty ? 'z_$zohoLineId' : _manualLineId(),
      name: _cleanLineName(line.name),
      description: _cleanNullable(line.description),
      rate: _safeRate(line.rate),
      qty: _safeQty(line.quantity.round()),
      zohoLineItemId: zohoLineId.isEmpty ? null : zohoLineId,
      zohoItemId: null,
    );
  }

  QuoteMetaState metaFromZoho(ZohoQuote quote) {
    final QuoteDraft draft = QuoteDraft.fromZohoQuote(quote);

    return QuoteMetaState(
      contact: _contactFromQuote(quote),
      reference: _cleanNullable(draft.reference),
      customerNotes: _cleanNullable(draft.customerNotes),
      saleContext: quote.saleContext,
      paymentContext: quote.paymentContext,
      quoteDate: normalizeDate(quote.date),
      expiryDate: normalizeDate(quote.expiryDate),
      deliveryAddress: quote.deliveryAddress,
      patientSnapshot: quote.patientSnapshot,
      membershipId: quote.resolvedMembershipId,
      prescriptionId: quote.resolvedPrescriptionId,
      prescriptionLabel: quote.resolvedPrescriptionId,
    );
  }

  ZohoContact? _contactFromQuote(ZohoQuote quote) {
    final String customerId = _cleanNullable(quote.customerId) ?? '';
    final String customerName = _cleanNullable(quote.customerName) ?? '';

    if (customerId.isEmpty && customerName.isEmpty) return null;

    return ZohoContact.fromJson(<String, Object?>{
      if (customerId.isNotEmpty) 'contact_id': customerId,
      if (customerId.isNotEmpty) 'contactId': customerId,
      'contact_type': 'customer',
      'contactType': 'customer',
      'display_name': customerName.isNotEmpty ? customerName : 'Customer',
      'contact_name': customerName.isNotEmpty ? customerName : 'Customer',
      'customer_name': customerName.isNotEmpty ? customerName : 'Customer',
      'company_name': customerName.isNotEmpty ? customerName : 'Customer',
    });
  }

  // ───────────────────────── Validation ─────────────────────────

  String? validateForSubmitV2({
    required QuoteMetaState meta,
    required bool requirePrices,
    required bool isEditing,
  }) {
    final String? lineError = _validateLines(
      requirePrices: requirePrices,
      isEditing: isEditing,
    );

    if (lineError != null) return lineError;

    if (!isEditing && meta.customerIdResolved.trim().isEmpty) {
      return 'Please pick a customer';
    }

    if (meta.quoteDate == null) {
      return 'Please select a quote date';
    }

    if (meta.requiresPatient && !_hasPatientContext(meta)) {
      return 'Please select a patient profile';
    }

    if (meta.requiresDeliveryAddress &&
        !_hasDeliveryAddress(meta.deliveryAddress)) {
      return 'Please select a delivery address';
    }

    if (meta.requiresMembership && !meta.hasInsuranceContext) {
      return 'Please select an insurance membership';
    }

    if (meta.requiresPrescription && !meta.hasPrescriptionContext) {
      return 'Please select a verified prescription';
    }

    if (meta.isGeneral && meta.isInsurancePayment) {
      return 'Insurance payment requires a clinical quote';
    }

    return null;
  }

  String? _validateLines({
    required bool requirePrices,
    required bool isEditing,
  }) {
    if (_lines.lines.isEmpty) {
      return isEditing ? 'Quote has no items' : 'Add at least one item';
    }

    final bool hasUnnamedManual = _lines.lines.whereType<ManualQuoteLine>().any(
      (ManualQuoteLine line) => line.name.trim().isEmpty,
    );

    if (hasUnnamedManual) {
      return 'Some items are missing a name. Please edit them.';
    }

    final int missingPrices = _lines.missingPriceLineCount;
    if (requirePrices && missingPrices > 0) {
      return '$missingPrices item(s) missing price.';
    }

    return null;
  }

  bool _hasPatientContext(QuoteMetaState meta) {
    final String patientId = _cleanNullable(meta.resolvedPatientId) ?? '';
    return patientId.isNotEmpty && meta.patientSnapshot != null;
  }

  bool _hasDeliveryAddress(SalesDocumentAddress? address) {
    return address?.isUsable == true;
  }

  int missingPriceLineCount() => _lines.missingPriceLineCount;

  // ───────────────────────── Payload building ─────────────────────────

  QuoteDraft buildPayloadDraftFromMeta({
    required QuoteMetaState meta,
    required bool requirePrices,
  }) {
    final ZohoContact? contact = meta.contact;

    final String customerId = _cleanNullable(contact?.contactId) ?? '';
    final String customerName = _cleanNullable(contact?.title) ?? '';

    final QuotePaymentContext paymentContext =
        meta.saleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : meta.effectivePaymentContext;

    return QuoteDraft(
      contact: contact,
      contactId: customerId.isEmpty ? null : customerId,
      contactName: customerName.isEmpty ? null : customerName,
      reference: _cleanNullable(meta.reference),
      customerNotes: _cleanNullable(meta.customerNotes),
      saleContext: meta.saleContext,
      paymentContext: paymentContext,
      deliveryAddress: meta.deliveryAddress,
      patientId: meta.resolvedPatientId,
      patientSnapshot: meta.patientSnapshot,
      membershipId: meta.resolvedMembershipId,
      prescriptionId: meta.resolvedPrescriptionId,
      lines: _buildLineDrafts(requirePrices: requirePrices),
    );
  }

  List<QuoteLineDraft> _buildLineDrafts({required bool requirePrices}) {
    return _lines.lines
        .map(
          (QuoteLine line) => switch (line) {
            CatalogQuoteLine catalogLine => _draftFromCatalogLine(
              catalogLine,
              requirePrices: requirePrices,
            ),
            ManualQuoteLine manualLine => _draftFromManualLine(
              manualLine,
              requirePrices: requirePrices,
            ),
          },
        )
        .toList(growable: false);
  }

  QuoteLineDraft _draftFromCatalogLine(
    CatalogQuoteLine line, {
    required bool requirePrices,
  }) {
    final String name = _cleanLineName(line.effectiveName);
    final String? description = _cleanNullable(line.effectiveDescription);
    final int quantity = _safeQty(line.qty);
    final num rate = requirePrices ? _safeRate(line.effectiveRate) : 0;

    final DiSalesTile tile = _toDiSalesTileFromCatalogLine(
      line,
      name: name,
      description: description,
    );

    return QuoteLineDraft(
      tile: tile,
      quantity: quantity,
      rate: rate,
      description: name,
      lineItemId: null,
      zohoItemId: null,
    );
  }

  QuoteLineDraft _draftFromManualLine(
    ManualQuoteLine line, {
    required bool requirePrices,
  }) {
    final String name = _cleanLineName(line.name);
    final String? description = _cleanNullable(line.description);
    final int quantity = _safeQty(line.qty);
    final num rate = requirePrices ? _safeRate(line.rate) : 0;

    final DiSalesTile tile = DiSalesTile.fallbackFromName(
      name: name,
      description: description,
      canonKey: line.manualId,
      groupKey: line.manualId,
    );

    return QuoteLineDraft(
      tile: tile,
      quantity: quantity,
      rate: rate,
      description: name,
      lineItemId: _cleanNullable(line.zohoLineItemId),
      zohoItemId: _cleanNullable(line.zohoItemId),
    );
  }

  // ───────────────────────── Service calls ─────────────────────────

  Future<ZohoQuote> create(
    QuoteDraft payload, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async {
    return (await _svc).createFromDraft(
      payload,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );
  }

  Future<ZohoQuote> update(
    String quoteId,
    QuoteDraft payload, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async {
    return (await _svc).updateFromDraft(
      quoteId,
      payload,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );
  }

  Future<void> delete(String quoteId) async {
    return (await _svc).delete(quoteId);
  }

  Future<Uint8List> getPdf(String quoteId) async {
    return (await _svc).getPdf(quoteId);
  }

  Future<void> email(String quoteId) async {
    return (await _svc).email(quoteId);
  }

  Future<void> markSent(String quoteId) async {
    return (await _svc).markSent(quoteId);
  }

  Future<void> emailAndMarkSent(String quoteId) async {
    return (await _svc).emailAndMarkSent(quoteId);
  }

  Future<QuoteConversionResult> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? membershipId,
    String? prescriptionId,
    SalesDocumentPatientSnapshot? patientSnapshot,
    SalesDocumentAddress? deliveryAddress,
  }) async {
    return (await _svc).convertToInvoice(
      quoteId,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      membershipId: membershipId,
      prescriptionId: prescriptionId,
      patientSnapshot: patientSnapshot,
      deliveryAddress: deliveryAddress,
    );
  }

  Future<QuoteConversionResult> convertDraftToInvoice(
    String quoteId,
    QuoteDraft draft, {
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) {
    return convertToInvoice(
      quoteId,
      invoiceDate: invoiceDate,
      dueDate: dueDate,
      membershipId: draft.resolvedMembershipId,
      prescriptionId: draft.resolvedPrescriptionId,
      patientSnapshot: draft.patientSnapshot,
      deliveryAddress: draft.deliveryAddress,
    );
  }

  // ───────────────────────── Mapping helpers ─────────────────────────

  static DiSalesTile _toDiSalesTileFromCatalogLine(
    CatalogQuoteLine line, {
    required String name,
    required String? description,
  }) {
    final CatalogTile tile = line.tile;
    final String key = tile.id;

    return DiSalesTile(
      canonKey: key,
      groupKey: key,
      tileTitle: name,
      tileDesc: _cleanNullable(description),
      form: _cleanNullable(tile.form),
      bestPackCount: tile.bestPackCount,
      offerCount: tile.offerCount ?? 0,
      bestSellPrice: line.effectiveRate,
      bestSupplier: _cleanNullable(tile.bestSupplier),
      priceRequestRequired: null,
    );
  }

  static String _manualLineId() {
    return 'm_${DateTime.now().microsecondsSinceEpoch}';
  }

  static String _cleanLineName(String? value) {
    return _cleanNullable(value) ?? 'Item';
  }

  static String? _cleanNullable(String? value) {
    final String cleaned = (value ?? '').trim();
    return cleaned.isEmpty ? null : cleaned;
  }

  static int _safeQty(int value) {
    if (value < 1) return 1;
    if (value > 9999) return 9999;
    return value;
  }

  static num _safeRate(num value) {
    if (value.isNaN || value.isInfinite || value < 0) return 0;
    return value;
  }
}
