// lib/features/retail/quotes/models/zoho_quote.dart

typedef JsonMap = Map<String, dynamic>;

class ZohoQuote {
  const ZohoQuote({
    required this.quoteId,
    required this.customerName,
    required this.status,
    required this.date,
    required this.total,
    this.referenceNumber,
    this.currencyCode,
  });

  final String quoteId;
  final String customerName;
  final String status; // "draft", "sent", etc. keep open-ended
  final DateTime? date;
  final num total;

  final String? referenceNumber;
  final String? currencyCode;

  factory ZohoQuote.fromJson(JsonMap j) {
    final id = (j['estimate_id'] ?? j['quote_id'] ?? j['id'] ?? '').toString();
    final name = (j['customer_name'] ?? j['contact_name'] ?? '').toString();
    final status = (j['status'] ?? '').toString();

    DateTime? date;
    final rawDate = j['date'] ?? j['estimate_date'];
    if (rawDate is String && rawDate.trim().isNotEmpty) {
      date = DateTime.tryParse(rawDate.trim());
    }

    final totalRaw = j['total'];
    final total = totalRaw is num ? totalRaw : num.tryParse('$totalRaw') ?? 0;

    return ZohoQuote(
      quoteId: id,
      customerName: name,
      status: status,
      date: date,
      total: total,
      referenceNumber:
          (j['reference_number'] ?? j['reference'] ?? '')
              .toString()
              .trim()
              .isEmpty
          ? null
          : (j['reference_number'] ?? j['reference']).toString(),
      currencyCode: (j['currency_code'] ?? '').toString().trim().isEmpty
          ? null
          : (j['currency_code']).toString(),
    );
  }
}
