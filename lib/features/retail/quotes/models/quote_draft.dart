import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'di_sales_tile.dart';

class QuoteLineDraft {
  const QuoteLineDraft({
    required this.tile,
    required this.quantity,
    required this.rate,
    this.description,
  });

  final DiSalesTile tile;
  final int quantity;
  final num rate;

  /// Optional line description (since you're not using Zoho Items).
  final String? description;

  num get amount => rate * quantity;

  QuoteLineDraft copyWith({
    int? quantity,
    num? rate,
    String? description,
    bool clearDescription = false,
  }) {
    return QuoteLineDraft(
      tile: tile,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
    );
  }
}

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

  /// Full Zoho contact (only available in create mode OR if you hydrate it in edit/preview).
  final ZohoContact? contact;

  /// Lightweight fields from quote payload (edit/preview friendly).
  final String? contactId; // Zoho customer_id
  final String? contactName; // Zoho customer_name

  final String? customerNotes;
  final String? reference;

  /// Optional: show currency nicely in UI (e.g. "KES", "USD").
  final String? currencyCode;

  final List<QuoteLineDraft> lines;

  num get total => lines.fold<num>(0, (s, l) => s + l.amount);

  /// Best display label for header UI.
  String get displayContactName {
    final n1 = contact?.displayName.trim() ?? '';
    if (n1.isNotEmpty) return n1;

    final n2 = (contactName ?? '').trim();
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
    String? reference,
    List<QuoteLineDraft>? lines,

    String? currencyCode,
    bool clearCurrencyCode = false,
  }) {
    return QuoteDraft(
      contact: clearContact ? null : (contact ?? this.contact),

      contactId: clearContactId ? null : (contactId ?? this.contactId),
      contactName: clearContactName ? null : (contactName ?? this.contactName),

      customerNotes: customerNotes ?? this.customerNotes,
      reference: reference ?? this.reference,
      lines: lines ?? this.lines,

      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
    );
  }
}
