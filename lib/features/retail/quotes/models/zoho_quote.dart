// lib/features/retail/sales/quotes/models/zoho_quote.dart

import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/shared/utils/parse/dates.dart';
import 'package:afyakit/shared/utils/parse/primitives.dart';

import 'package:afyakit/shared/utils/utils.dart';

class ZohoQuote {
  const ZohoQuote({
    required this.quoteId,
    required this.customerName,
    required this.status,
    required this.date,
    required this.total,
    this.expiryDate, // ✅ NEW
    this.referenceNumber,
    this.currencyCode,
    this.customerId,
    this.notes,
    this.terms,
    this.lineItems = const <ZohoQuoteLineItem>[],
  });

  final String quoteId;
  final String customerName;
  final String status;

  /// Zoho: `date` (estimate_date)
  final DateTime? date;

  /// ✅ NEW: Zoho `expiry_date`
  final DateTime? expiryDate;

  final num total;

  final String? referenceNumber;
  final String? currencyCode;
  final String? customerId;
  final String? notes;
  final String? terms;

  final List<ZohoQuoteLineItem> lineItems;

  factory ZohoQuote.fromJson(JsonMap j) {
    final id = asTrimmedString(j['estimate_id'] ?? j['quote_id'] ?? j['id']);
    final name = asTrimmedString(j['customer_name'] ?? j['contact_name']);
    final status = asTrimmedString(j['status']);

    final date = parseDate(j['date'] ?? j['estimate_date']);
    final expiryDate = parseDate(j['expiry_date']); // ✅ NEW

    final total = asNum(j['total']);

    final reference = asCleanStringOrNull(
      j['reference_number'] ?? j['reference'],
    );
    final currency = asCleanStringOrNull(j['currency_code']);
    final customerId = asCleanStringOrNull(j['customer_id']);
    final notes = asCleanStringOrNull(j['notes']);
    final terms = asCleanStringOrNull(j['terms']);

    final rawLines = j['line_items'];
    final lines = <ZohoQuoteLineItem>[];
    if (rawLines is List) {
      for (final e in rawLines) {
        if (e is Map) {
          lines.add(ZohoQuoteLineItem.fromJson(e.cast<String, dynamic>()));
        }
      }
    }

    return ZohoQuote(
      quoteId: id,
      customerName: name,
      status: status,
      date: date,
      expiryDate: expiryDate, // ✅ NEW
      total: total,
      referenceNumber: reference,
      currencyCode: currency,
      customerId: customerId,
      notes: notes,
      terms: terms,
      lineItems: lines,
    );
  }
}
