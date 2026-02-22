// lib/features/retail/quotes/models/zoho_quote.dart

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
    this.expiryDate,
    this.accountNumber, // ✅ renamed
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

  /// Zoho: `expiry_date`
  final DateTime? expiryDate;

  final num total;

  /// ✅ Deterministic member scope key (your app)
  /// Prefer backend-provided `account_number`.
  /// Fallback to `reference_number` temporarily for backward compatibility.
  final String? accountNumber;

  final String? currencyCode;
  final String? customerId;
  final String? notes;
  final String? terms;

  final List<ZohoQuoteLineItem> lineItems;

  factory ZohoQuote.fromJson(JsonMap j) {
    final id = _asTrimmed(j['estimate_id'] ?? j['quote_id'] ?? j['id']);
    final name = _asTrimmed(j['customer_name'] ?? j['contact_name']);
    final status = _asTrimmed(j['status']);

    final date = parseDate(j['date'] ?? j['estimate_date']);
    final expiryDate = parseDate(j['expiry_date']);

    final total = asNum(j['total']);

    // ✅ account number (preferred)
    final accountNumber = _asCleanOrNull(
      j['account_number'] ?? j['accountNumber'] ?? j['reference_number'],
    );

    final currency = _asCleanOrNull(j['currency_code']);
    final customerId = _asCleanOrNull(j['customer_id']);
    final notes = _asCleanOrNull(j['notes']);
    final terms = _asCleanOrNull(j['terms']);

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
      expiryDate: expiryDate,
      total: total,
      accountNumber: accountNumber,
      currencyCode: currency,
      customerId: customerId,
      notes: notes,
      terms: terms,
      lineItems: lines,
    );
  }

  static String _asTrimmed(Object? v) {
    final s = asTrimmedString(v);
    return s.isEmpty ? '' : s;
  }

  static String? _asCleanOrNull(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }
}
