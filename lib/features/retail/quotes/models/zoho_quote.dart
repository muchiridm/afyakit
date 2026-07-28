// lib/features/retail/quotes/models/zoho_quote.dart

import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
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
    this.accountNumber,
    this.currencyCode,
    this.customerId,
    this.notes,
    this.terms,
    this.deliveryAddress,
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

  /// Prefer backend-provided `account_number`.
  final String? accountNumber;

  final String? currencyCode;
  final String? customerId;
  final String? notes;
  final String? terms;

  /// Snapshot of the chosen delivery address at document time.
  final SalesDocumentAddress? deliveryAddress;

  final List<ZohoQuoteLineItem> lineItems;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  factory ZohoQuote.fromJson(JsonMap j) {
    final id = _asTrimmed(j['estimate_id'] ?? j['quote_id'] ?? j['id']);
    final name = _asTrimmed(j['customer_name'] ?? j['contact_name']);
    final status = _asTrimmed(j['status']);

    final date = parseDate(j['date'] ?? j['estimate_date']);
    final expiryDate = parseDate(j['expiry_date']);

    final total = asNum(j['total']);

    final accountNumber = _asCleanOrNull(
      j['account_number'] ?? j['accountNumber'] ?? j['reference_number'],
    );

    final currency = _asCleanOrNull(j['currency_code']);
    final customerId = _asCleanOrNull(j['customer_id']);
    final notes = _asCleanOrNull(j['notes']);
    final terms = _asCleanOrNull(j['terms']);

    final deliveryAddress = _parseDeliveryAddress(
      j['delivery_address'] ?? j['deliveryAddress'] ?? j['shipping_address'],
    );

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
      deliveryAddress: deliveryAddress,
      lineItems: lines,
    );
  }

  static SalesDocumentAddress? _parseDeliveryAddress(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final parsed = SalesDocumentAddress.fromJson(raw);
      return parsed.isUsable ? parsed : null;
    }
    if (raw is Map) {
      final parsed = SalesDocumentAddress.fromJson(raw.cast<String, dynamic>());
      return parsed.isUsable ? parsed : null;
    }
    return null;
  }

  static String _asTrimmed(Object? v) {
    final s = asTrimmedString(v);
    return s.isEmpty ? '' : s;
  }

  static String? _asCleanOrNull(Object? v) {
    final s = (v ?? '').toString().trim();
    return s.isEmpty ? null : s;
  }

  ZohoQuote copyWith({
    String? quoteId,
    String? customerName,
    String? status,
    DateTime? date,
    DateTime? expiryDate,
    num? total,
    String? accountNumber,
    String? currencyCode,
    String? customerId,
    String? notes,
    String? terms,
    SalesDocumentAddress? deliveryAddress,
    List<ZohoQuoteLineItem>? lineItems,
  }) {
    return ZohoQuote(
      quoteId: quoteId ?? this.quoteId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      date: date ?? this.date,
      expiryDate: expiryDate ?? this.expiryDate,
      total: total ?? this.total,
      accountNumber: accountNumber ?? this.accountNumber,
      currencyCode: currencyCode ?? this.currencyCode,
      customerId: customerId ?? this.customerId,
      notes: notes ?? this.notes,
      terms: terms ?? this.terms,
      deliveryAddress: deliveryAddress ?? this.deliveryAddress,
      lineItems: lineItems ?? this.lineItems,
    );
  }
}
