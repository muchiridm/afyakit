import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';

import 'di_sales_tile.dart';
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

  int get safeQty => quantity < 0 ? 0 : quantity;
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
  }) {
    return QuoteLineDraft(
      tile: tile ?? this.tile,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
      zohoItemId: clearZohoItemId ? null : (zohoItemId ?? this.zohoItemId),
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

  final String? currencyCode;

  final List<QuoteLineDraft> lines;

  String get customerIdResolved =>
      (contactId ?? contact?.contactId ?? '').trim();

  bool get hasCustomer => customerIdResolved.isNotEmpty;

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
          );
        })
        .toList(growable: false);

    return QuoteDraft(
      contactId: (q.customerId ?? '').trim().isEmpty ? null : q.customerId,
      contactName: q.customerName.trim().isEmpty ? null : q.customerName.trim(),
      customerNotes: q.notes,
      reference: q.accountNumber,
      deliveryAddress: q.deliveryAddress,
      currencyCode: q.currencyCode,
      lines: hydratedLines,
    );
  }
}
