import 'package:flutter/foundation.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';

import 'package:afyakit/features/retail/sales/quotes/models/di_sales_tile.dart';
import 'zoho_invoice.dart';

@immutable
class InvoiceLineDraft {
  const InvoiceLineDraft({
    required this.tile,
    required this.quantity,
    required this.rate,
    this.description,
    this.lineItemId,
  });

  final DiSalesTile tile;
  final int quantity;
  final num rate;

  final String? description;

  /// ✅ Zoho line_item_id (present when editing existing invoices)
  final String? lineItemId;

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

  InvoiceLineDraft copyWith({
    int? quantity,
    num? rate,
    String? description,
    bool clearDescription = false,
    String? lineItemId,
    bool clearLineItemId = false,
  }) {
    return InvoiceLineDraft(
      tile: tile,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
    );
  }
}

@immutable
class InvoiceDraft {
  const InvoiceDraft({
    this.contact,
    this.contactId,
    this.contactName,
    this.customerNotes,
    this.reference,
    this.lines = const <InvoiceLineDraft>[],
    this.currencyCode,
    this.dueDate,
  });

  final ZohoContact? contact;

  final String? contactId; // Zoho customer_id
  final String? contactName; // Zoho customer_name

  final String? customerNotes;
  final String? reference;

  final String? currencyCode;

  final DateTime? dueDate;

  final List<InvoiceLineDraft> lines;

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

  InvoiceDraft copyWith({
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
    List<InvoiceLineDraft>? lines,
    bool clearLines = false,
    String? currencyCode,
    bool clearCurrencyCode = false,
    DateTime? dueDate,
    bool clearDueDate = false,
  }) {
    return InvoiceDraft(
      contact: clearContact ? null : (contact ?? this.contact),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      contactName: clearContactName ? null : (contactName ?? this.contactName),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
      reference: clearReference ? null : (reference ?? this.reference),
      lines: clearLines ? const <InvoiceLineDraft>[] : (lines ?? this.lines),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
      dueDate: clearDueDate ? null : (dueDate ?? this.dueDate),
    );
  }

  InvoiceDraft upsertLine(InvoiceLineDraft next) {
    final nextKey = next.key;
    final idx = lines.indexWhere((l) => l.key == nextKey);

    if (next.safeQty == 0) {
      if (idx < 0) return this;
      final copy = List<InvoiceLineDraft>.from(lines)..removeAt(idx);
      return copyWith(lines: copy);
    }

    if (idx < 0) {
      final copy = List<InvoiceLineDraft>.from(lines)..add(next);
      return copyWith(lines: copy);
    }

    final copy = List<InvoiceLineDraft>.from(lines)..[idx] = next;
    return copyWith(lines: copy);
  }

  InvoiceDraft removeLineByKey(String key) {
    final k = key.trim();
    if (k.isEmpty) return this;
    final idx = lines.indexWhere((l) => l.key == k);
    if (idx < 0) return this;
    final copy = List<InvoiceLineDraft>.from(lines)..removeAt(idx);
    return copyWith(lines: copy);
  }

  InvoiceDraft clearCustomer() {
    return copyWith(
      clearContact: true,
      clearContactId: true,
      clearContactName: true,
    );
  }

  // ✅ Edit-mode hydration helper
  factory InvoiceDraft.fromZohoInvoice(ZohoInvoice inv) {
    final hydratedLines = inv.lineItems
        .map((li) {
          final tile = DiSalesTile.fallbackFromName(
            name: li.name,
            description: li.description,
          );

          return InvoiceLineDraft(
            tile: tile,
            quantity: li.quantity.round(),
            rate: li.rate,
            description: li.name,
            lineItemId: li.lineItemId,
          );
        })
        .toList(growable: false);

    return InvoiceDraft(
      contactId: (inv.customerId ?? '').trim().isEmpty ? null : inv.customerId,
      contactName: (inv.customerName).trim().isEmpty ? null : inv.customerName,
      customerNotes: inv.notes,
      reference: inv.referenceNumber,
      currencyCode: inv.currencyCode,
      dueDate: inv.dueDate,
      lines: hydratedLines,
    );
  }
}
