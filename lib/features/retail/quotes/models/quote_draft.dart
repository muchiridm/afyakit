// lib/features/retail/quotes/models/quote_draft.dart

import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/contacts/zoho_contact.dart';

import '../../catalog/models/di_sales_tile.dart';
import 'zoho_quote.dart';

@immutable
class QuoteLineDraft {
  const QuoteLineDraft({
    required this.tile,
    required this.quantity,
    required this.rate,
    this.description,
    this.lineItemId,
    this.zohoItemId,
    this.unit,
  });

  final DiSalesTile tile;
  final int quantity;
  final num rate;

  /// Line description (Zoho: `description`)
  final String? description;

  /// Zoho `line_item_id` (present when editing existing quotes)
  final String? lineItemId;

  /// Zoho `item_id` (links to a product/service item)
  final String? zohoItemId;

  /// Optional Zoho line unit.
  final String? unit;

  /// Stable identity for upsert/remove.
  /// If Zoho line_item_id exists, it MUST win.
  String get key {
    final String id = (lineItemId ?? '').trim();
    if (id.isNotEmpty) return id;

    final String c = tile.canonKey.trim();
    if (c.isNotEmpty) return c;

    final String g = tile.groupKey.trim();
    if (g.isNotEmpty) return g;

    final String t = tile.tileTitle.trim();
    return t.isNotEmpty ? t : 'line';
  }

  int get safeQty {
    if (quantity < 0) return 0;
    if (quantity > 9999) return 9999;
    return quantity;
  }

  num get safeRate => (rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate;

  num get amount => safeRate * safeQty;

  QuoteLineDraft copyWith({
    DiSalesTile? tile,
    int? quantity,
    num? rate,
    String? description,
    bool clearDescription = false,
    String? lineItemId,
    bool clearLineItemId = false,
    String? zohoItemId,
    bool clearZohoItemId = false,
    String? unit,
    bool clearUnit = false,
  }) {
    return QuoteLineDraft(
      tile: tile ?? this.tile,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
      zohoItemId: clearZohoItemId ? null : (zohoItemId ?? this.zohoItemId),
      unit: clearUnit ? null : (unit ?? this.unit),
    );
  }
}

@immutable
class QuoteDraft {
  const QuoteDraft({
    this.contact,
    this.contactId,
    this.contactName,
    this.customerNotes,
    this.reference,
    this.deliveryAddress,
    this.patientId,
    this.patientSnapshot,
    this.membershipId,
    this.lines = const <QuoteLineDraft>[],
    this.currencyCode,
  });

  final ZohoContact? contact;

  /// Lightweight fields from quote payload (edit/preview friendly).
  final String? contactId; // Zoho customer_id
  final String? contactName; // Zoho customer_name

  final String? customerNotes;
  final String? reference;

  final SalesDocumentAddress? deliveryAddress;

  /// App-level patient context.
  ///
  /// The Zoho customer remains the payer/contact.
  /// This is the person receiving care/medicine.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership context used later for:
  /// quote → invoice → insurance claim.
  final String? membershipId;

  final String? currencyCode;

  final List<QuoteLineDraft> lines;

  String get customerIdResolved =>
      (contactId ?? contact?.contactId ?? '').trim();

  bool get hasCustomer => customerIdResolved.isNotEmpty;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get hasLines => lines.any((QuoteLineDraft l) => l.safeQty > 0);

  String? get resolvedPatientId {
    final String direct = (patientId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final String snap = (patientSnapshot?.patientId ?? '').trim();
    return snap.isEmpty ? null : snap;
  }

  String? get resolvedMembershipId {
    final String direct = (membershipId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final String snap = (patientSnapshot?.membershipId ?? '').trim();
    return snap.isEmpty ? null : snap;
  }

  bool get hasPatientContext => resolvedPatientId != null;

  bool get hasInsuranceContext => resolvedMembershipId != null;

  bool get canCreateQuote {
    return hasCustomer && hasPatientContext && hasDeliveryAddress && hasLines;
  }

  num get total =>
      lines.fold<num>(0, (num s, QuoteLineDraft l) => s + l.amount);

  String get displayContactName {
    final String n1 = (contact?.displayName ?? '').trim();
    if (n1.isNotEmpty) return n1;

    final String n2 = (contactName ?? '').trim();
    if (n2.isNotEmpty) return n2;

    return '';
  }

  QuoteDraft copyWith({
    ZohoContact? contact,
    bool clearContact = false,
    String? contactId,
    bool clearContactId = false,
    String? contactName,
    bool clearContactName = false,
    String? customerNotes,
    bool clearCustomerNotes = false,
    String? reference,
    bool clearReference = false,
    SalesDocumentAddress? deliveryAddress,
    bool clearDeliveryAddress = false,
    String? patientId,
    bool clearPatientId = false,
    SalesDocumentPatientSnapshot? patientSnapshot,
    bool clearPatientSnapshot = false,
    String? membershipId,
    bool clearMembershipId = false,
    List<QuoteLineDraft>? lines,
    bool clearLines = false,
    String? currencyCode,
    bool clearCurrencyCode = false,
  }) {
    return QuoteDraft(
      contact: clearContact ? null : (contact ?? this.contact),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      contactName: clearContactName ? null : (contactName ?? this.contactName),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
      reference: clearReference ? null : (reference ?? this.reference),
      deliveryAddress: clearDeliveryAddress
          ? null
          : (deliveryAddress ?? this.deliveryAddress),
      patientId: clearPatientId ? null : (patientId ?? this.patientId),
      patientSnapshot: clearPatientSnapshot
          ? null
          : (patientSnapshot ?? this.patientSnapshot),
      membershipId: clearMembershipId
          ? null
          : (membershipId ?? this.membershipId),
      lines: clearLines ? const <QuoteLineDraft>[] : (lines ?? this.lines),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
    );
  }

  QuoteDraft upsertLine(QuoteLineDraft next) {
    final String nextKey = next.key;
    final int idx = lines.indexWhere((QuoteLineDraft l) => l.key == nextKey);

    if (next.safeQty == 0) {
      if (idx < 0) return this;
      final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
        ..removeAt(idx);
      return copyWith(lines: copy);
    }

    if (idx < 0) {
      final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
        ..add(next);
      return copyWith(lines: copy);
    }

    final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
      ..[idx] = next;
    return copyWith(lines: copy);
  }

  QuoteDraft removeLineByKey(String key) {
    final String k = key.trim();
    if (k.isEmpty) return this;

    final int idx = lines.indexWhere((QuoteLineDraft l) => l.key == k);
    if (idx < 0) return this;

    final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
      ..removeAt(idx);

    return copyWith(lines: copy);
  }

  QuoteDraft clearCustomer() {
    return copyWith(
      clearContact: true,
      clearContactId: true,
      clearContactName: true,
    );
  }

  QuoteDraft clearPatientContext() {
    return copyWith(
      clearPatientId: true,
      clearPatientSnapshot: true,
      clearMembershipId: true,
    );
  }

  QuoteDraft withPatientSnapshot(SalesDocumentPatientSnapshot snapshot) {
    return copyWith(
      patientId: snapshot.patientId,
      patientSnapshot: snapshot,
      membershipId: snapshot.membershipId,
    );
  }

  factory QuoteDraft.fromZohoQuote(ZohoQuote q) {
    final List<QuoteLineDraft> hydratedLines = q.lineItems
        .map((ZohoQuoteLineItem li) {
          final String stableKey = (li.lineItemId ?? '').trim();

          final DiSalesTile tile = stableKey.isNotEmpty
              ? DiSalesTile.fallbackFromName(
                  name: li.name,
                  description: li.description,
                  canonKey: stableKey,
                  groupKey: stableKey,
                )
              : DiSalesTile.fallbackFromName(
                  name: li.name,
                  description: li.description,
                );

          return QuoteLineDraft(
            tile: tile,
            quantity: li.quantity.round(),
            rate: li.rate,
            description: (li.description ?? '').trim().isEmpty
                ? null
                : li.description,
            lineItemId: stableKey.isEmpty ? null : stableKey,
            zohoItemId: null,
            unit: (li.unit ?? '').trim().isEmpty ? null : li.unit,
          );
        })
        .toList(growable: false);

    return QuoteDraft(
      contactId: (q.customerId ?? '').trim().isEmpty ? null : q.customerId,
      contactName: q.customerName.trim().isEmpty ? null : q.customerName.trim(),
      customerNotes: q.notes,
      reference: q.accountNumber,
      deliveryAddress: q.deliveryAddress,
      patientId: q.resolvedPatientId,
      patientSnapshot: q.patientSnapshot,
      membershipId: q.resolvedMembershipId,
      currencyCode: q.currencyCode,
      lines: hydratedLines,
    );
  }
}
