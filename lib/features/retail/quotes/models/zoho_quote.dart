// lib/features/retail/quotes/models/zoho_quote.dart

import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
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
    this.patientId,
    this.patientSnapshot,
    this.membershipId,
    this.lineItems = const <ZohoQuoteLineItem>[],
  });

  final String quoteId;
  final String customerName;
  final String status;

  /// Zoho: `date` / `estimate_date`
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

  /// App-level patient context.
  ///
  /// Zoho customer/contact remains the payer/customer.
  /// This is the person receiving care/medicine.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership used later when converting quote → invoice → claim.
  final String? membershipId;

  final List<ZohoQuoteLineItem> lineItems;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get hasPatientContext {
    final direct = (patientId ?? '').trim();
    final snap = (patientSnapshot?.patientId ?? '').trim();
    return direct.isNotEmpty || snap.isNotEmpty;
  }

  bool get hasInsuranceContext {
    final direct = (membershipId ?? '').trim();
    final snap = (patientSnapshot?.membershipId ?? '').trim();
    return direct.isNotEmpty || snap.isNotEmpty;
  }

  String? get resolvedPatientId {
    final direct = (patientId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final snap = (patientSnapshot?.patientId ?? '').trim();
    return snap.isEmpty ? null : snap;
  }

  String? get resolvedMembershipId {
    final direct = (membershipId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final snap = (patientSnapshot?.membershipId ?? '').trim();
    return snap.isEmpty ? null : snap;
  }

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

    final patientSnapshot = _parsePatientSnapshot(j['patient_snapshot']);
    final patientId =
        _asCleanOrNull(j['patient_id']) ?? patientSnapshot?.patientId;

    final membershipId =
        _asCleanOrNull(j['membership_id']) ?? patientSnapshot?.membershipId;

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
      patientId: patientId,
      patientSnapshot: patientSnapshot,
      membershipId: membershipId,
      lineItems: lines,
    );
  }

  JsonMap toJson() {
    return <String, dynamic>{
      'estimate_id': quoteId,
      'customer_name': customerName,
      'status': status,
      'date': date?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'total': total,
      'account_number': accountNumber,
      'currency_code': currencyCode,
      'customer_id': customerId,
      'notes': notes,
      'terms': terms,
      'delivery_address': deliveryAddress?.toJson(),
      'patient_id': patientId,
      'patient_snapshot': patientSnapshot?.toJson(),
      'membership_id': membershipId,
      'line_items': lineItems.map((e) => e.toJson()).toList(growable: false),
    }..removeWhere(_removeEmpty);
  }

  static SalesDocumentPatientSnapshot? _parsePatientSnapshot(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final parsed = SalesDocumentPatientSnapshot.fromJson(raw);
      return parsed.patientId.trim().isEmpty ? null : parsed;
    }

    if (raw is Map) {
      final parsed = SalesDocumentPatientSnapshot.fromJson(
        raw.cast<String, dynamic>(),
      );
      return parsed.patientId.trim().isEmpty ? null : parsed;
    }

    return null;
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

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    if (value is List && value.isEmpty) return true;
    if (value is Map && value.isEmpty) return true;
    return false;
  }

  ZohoQuote copyWith({
    String? quoteId,
    String? customerName,
    String? status,
    DateTime? date,
    DateTime? expiryDate,
    num? total,
    String? accountNumber,
    bool clearAccountNumber = false,
    String? currencyCode,
    bool clearCurrencyCode = false,
    String? customerId,
    bool clearCustomerId = false,
    String? notes,
    bool clearNotes = false,
    String? terms,
    bool clearTerms = false,
    SalesDocumentAddress? deliveryAddress,
    bool clearDeliveryAddress = false,
    String? patientId,
    bool clearPatientId = false,
    SalesDocumentPatientSnapshot? patientSnapshot,
    bool clearPatientSnapshot = false,
    String? membershipId,
    bool clearMembershipId = false,
    List<ZohoQuoteLineItem>? lineItems,
  }) {
    return ZohoQuote(
      quoteId: quoteId ?? this.quoteId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      date: date ?? this.date,
      expiryDate: expiryDate ?? this.expiryDate,
      total: total ?? this.total,
      accountNumber: clearAccountNumber
          ? null
          : (accountNumber ?? this.accountNumber),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      notes: clearNotes ? null : (notes ?? this.notes),
      terms: clearTerms ? null : (terms ?? this.terms),
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
      lineItems: lineItems ?? this.lineItems,
    );
  }
}
