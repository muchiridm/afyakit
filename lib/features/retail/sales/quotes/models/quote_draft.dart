// lib/features/retail/sales/quotes/models/quote_draft.dart

import 'package:flutter/foundation.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';

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
  });

  final DiSalesTile tile;
  final int quantity;
  final num rate;

  /// Optional line description (since you're not using Zoho Items).
  /// In your payload builder this becomes Zoho 'name' (and tileDesc is 'description').
  final String? description;

  /// ✅ Zoho line_item_id (present when editing existing quotes)
  final String? lineItemId;

  /// Stable identity for update/remove operations.
  String get key {
    final c = (tile.canonKey).trim();
    if (c.isNotEmpty) return c;

    final g = (tile.groupKey).trim();
    if (g.isNotEmpty) return g;

    final t = (tile.tileTitle).trim();
    return t.isNotEmpty ? t : 'line';
  }

  int get safeQty => quantity < 0 ? 0 : quantity;
  num get safeRate => (rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate;

  num get amount => safeRate * safeQty;

  QuoteLineDraft copyWith({
    DiSalesTile? tile, // ✅ NEW: allow updating tile (manual line edits)
    int? quantity,
    num? rate,
    String? description,
    bool clearDescription = false,
    String? lineItemId,
    bool clearLineItemId = false,
  }) {
    return QuoteLineDraft(
      tile: tile ?? this.tile, // ✅ NEW
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
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
    this.lines = const <QuoteLineDraft>[],
    this.currencyCode,
  });

  final ZohoContact? contact;

  /// Lightweight fields from quote payload (edit/preview friendly).
  final String? contactId; // Zoho customer_id
  final String? contactName; // Zoho customer_name

  final String? customerNotes;
  final String? reference;

  final String? currencyCode;

  final List<QuoteLineDraft> lines;

  // ─────────────────────────────────────────────
  // Derived helpers
  // ─────────────────────────────────────────────

  String get customerIdResolved =>
      (contactId ?? contact?.contactId ?? '').trim();

  bool get hasCustomer => customerIdResolved.isNotEmpty;

  num get total => lines.fold<num>(0, (s, l) => s + l.amount);

  String get displayContactName {
    final n1 = (contact?.displayName ?? '').trim();
    if (n1.isNotEmpty) return n1;

    final n2 = (contactName ?? '').trim();
    if (n2.isNotEmpty) return n2;

    return '';
  }

  // ─────────────────────────────────────────────
  // Copy / edit helpers
  // ─────────────────────────────────────────────

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
      lines: clearLines ? const <QuoteLineDraft>[] : (lines ?? this.lines),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
    );
  }

  QuoteDraft upsertLine(QuoteLineDraft next) {
    final nextKey = next.key;
    final idx = lines.indexWhere((l) => l.key == nextKey);

    if (next.safeQty == 0) {
      if (idx < 0) return this;
      final copy = List<QuoteLineDraft>.from(lines)..removeAt(idx);
      return copyWith(lines: copy);
    }

    if (idx < 0) {
      final copy = List<QuoteLineDraft>.from(lines)..add(next);
      return copyWith(lines: copy);
    }

    final copy = List<QuoteLineDraft>.from(lines)..[idx] = next;
    return copyWith(lines: copy);
  }

  QuoteDraft removeLineByKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return this;
    final idx = lines.indexWhere((l) => l.key == k);
    if (idx < 0) return this;
    final copy = List<QuoteLineDraft>.from(lines)..removeAt(idx);
    return copyWith(lines: copy);
  }

  QuoteDraft clearCustomer() {
    return copyWith(
      clearContact: true,
      clearContactId: true,
      clearContactName: true,
    );
  }

  // ─────────────────────────────────────────────
  // ✅ Hydration helper for EDIT mode
  // ─────────────────────────────────────────────

  factory QuoteDraft.fromZohoQuote(ZohoQuote q) {
    final hydratedLines = q.lineItems
        .map((li) {
          final stableKey = (li.lineItemId ?? '').trim().isNotEmpty
              ? li.lineItemId!.trim()
              : '';

          final tile = stableKey.isNotEmpty
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

          final nameForDraft = li.name.trim().isEmpty ? null : li.name.trim();

          return QuoteLineDraft(
            tile: tile,
            quantity: li.quantity.round(),
            rate: li.rate,
            description: nameForDraft,
            lineItemId: (li.lineItemId ?? '').trim().isEmpty
                ? null
                : li.lineItemId,
          );
        })
        .toList(growable: false);

    return QuoteDraft(
      contactId: (q.customerId ?? '').trim().isEmpty ? null : q.customerId,
      contactName: q.customerName.trim().isEmpty ? null : q.customerName.trim(),
      customerNotes: q.notes,
      reference: q.referenceNumber,
      currencyCode: q.currencyCode,
      lines: hydratedLines,
    );
  }
}
