// lib/features/retail/quotes/models/zoho_quote.dart

import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
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
    this.saleContext = QuoteSaleContext.clinical,
    this.paymentContext = QuotePaymentContext.directPay,
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

  final DateTime? date;
  final DateTime? expiryDate;

  final num total;

  final QuoteSaleContext saleContext;
  final QuotePaymentContext paymentContext;

  final String? accountNumber;

  final String? currencyCode;
  final String? customerId;
  final String? notes;
  final String? terms;

  final SalesDocumentAddress? deliveryAddress;

  /// Patient receiving care/medicine.
  ///
  /// This is separate from [customerId], which is the payer/customer.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership, only meaningful for insurance payment context.
  final String? membershipId;

  final List<ZohoQuoteLineItem> lineItems;

  bool get isClinical => saleContext == QuoteSaleContext.clinical;

  bool get isGeneral => saleContext == QuoteSaleContext.general;

  bool get isDirectPay => paymentContext == QuotePaymentContext.directPay;

  bool get isInsurancePayment {
    return paymentContext == QuotePaymentContext.insurance;
  }

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get hasPatientContext {
    final String direct = (patientId ?? '').trim();
    final String snap = (patientSnapshot?.patientId ?? '').trim();
    return direct.isNotEmpty || snap.isNotEmpty;
  }

  bool get hasInsuranceContext {
    final String direct = (membershipId ?? '').trim();
    final String snap = (patientSnapshot?.membershipId ?? '').trim();
    return direct.isNotEmpty || snap.isNotEmpty;
  }

  bool get canCreateInsuranceClaim {
    return isClinical && isInsurancePayment && hasInsuranceContext;
  }

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

  factory ZohoQuote.fromJson(JsonMap json) {
    final String id = _asTrimmed(
      json['estimate_id'] ?? json['quote_id'] ?? json['id'],
    );

    final String name = _asTrimmed(
      json['customer_name'] ?? json['contact_name'],
    );

    final String status = _asTrimmed(json['status']);

    final DateTime? date = parseDate(json['date'] ?? json['estimate_date']);
    final DateTime? expiryDate = parseDate(json['expiry_date']);

    final num total = asNum(json['total']);

    final QuoteSaleContext saleContext = QuoteSaleContext.fromApi(
      json['sale_context'] ?? json['saleContext'],
    );

    final QuotePaymentContext paymentContext =
        saleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : QuotePaymentContext.fromApi(
            json['payment_context'] ?? json['paymentContext'],
          );

    final String? accountNumber = _asCleanOrNull(
      json['account_number'] ??
          json['accountNumber'] ??
          json['reference_number'],
    );

    final String? currency = _asCleanOrNull(json['currency_code']);
    final String? customerId = _asCleanOrNull(json['customer_id']);
    final String? notes = _asCleanOrNull(json['notes']);
    final String? terms = _asCleanOrNull(json['terms']);

    final SalesDocumentAddress? deliveryAddress = _parseDeliveryAddress(
      json['delivery_address'] ??
          json['deliveryAddress'] ??
          json['shipping_address'],
    );

    final SalesDocumentPatientSnapshot? patientSnapshot = _parsePatientSnapshot(
      json['patient_snapshot'],
    );

    final String? patientId =
        _asCleanOrNull(json['patient_id']) ?? patientSnapshot?.patientId;

    final String? membershipId =
        _asCleanOrNull(json['membership_id']) ?? patientSnapshot?.membershipId;

    final Object? rawLines = json['line_items'];
    final List<ZohoQuoteLineItem> lines = <ZohoQuoteLineItem>[];

    if (rawLines is List) {
      for (final Object? item in rawLines) {
        if (item is Map) {
          lines.add(ZohoQuoteLineItem.fromJson(item.cast<String, dynamic>()));
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
      saleContext: saleContext,
      paymentContext: paymentContext,
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
      'sale_context': saleContext.apiValue,
      'payment_context': saleContext == QuoteSaleContext.general
          ? QuotePaymentContext.directPay.apiValue
          : paymentContext.apiValue,
      'account_number': accountNumber,
      'currency_code': currencyCode,
      'customer_id': customerId,
      'notes': notes,
      'terms': terms,
      'delivery_address': deliveryAddress?.toJson(),
      'patient_id': patientId,
      'patient_snapshot': patientSnapshot?.toJson(),
      'membership_id': membershipId,
      'line_items': lineItems
          .map((ZohoQuoteLineItem item) => item.toJson())
          .toList(growable: false),
    }..removeWhere(_removeEmpty);
  }

  ZohoQuote copyWith({
    String? quoteId,
    String? customerName,
    String? status,
    DateTime? date,
    DateTime? expiryDate,
    num? total,
    QuoteSaleContext? saleContext,
    QuotePaymentContext? paymentContext,
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
    final QuoteSaleContext nextSaleContext = saleContext ?? this.saleContext;

    final QuotePaymentContext nextPaymentContext =
        nextSaleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : (paymentContext ?? this.paymentContext);

    return ZohoQuote(
      quoteId: quoteId ?? this.quoteId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      date: date ?? this.date,
      expiryDate: expiryDate ?? this.expiryDate,
      total: total ?? this.total,
      saleContext: nextSaleContext,
      paymentContext: nextPaymentContext,
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

  static SalesDocumentPatientSnapshot? _parsePatientSnapshot(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final SalesDocumentPatientSnapshot parsed =
          SalesDocumentPatientSnapshot.fromJson(raw);

      return parsed.patientId.trim().isEmpty ? null : parsed;
    }

    if (raw is Map) {
      final SalesDocumentPatientSnapshot parsed =
          SalesDocumentPatientSnapshot.fromJson(raw.cast<String, dynamic>());

      return parsed.patientId.trim().isEmpty ? null : parsed;
    }

    return null;
  }

  static SalesDocumentAddress? _parseDeliveryAddress(Object? raw) {
    if (raw is Map<String, dynamic>) {
      final SalesDocumentAddress parsed = SalesDocumentAddress.fromJson(raw);
      return parsed.isUsable ? parsed : null;
    }

    if (raw is Map) {
      final SalesDocumentAddress parsed = SalesDocumentAddress.fromJson(
        raw.cast<String, dynamic>(),
      );

      return parsed.isUsable ? parsed : null;
    }

    return null;
  }

  static String _asTrimmed(Object? value) {
    final String text = asTrimmedString(value);
    return text.isEmpty ? '' : text;
  }

  static String? _asCleanOrNull(Object? value) {
    final String text = (value ?? '').toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool _removeEmpty(Object? _, Object? value) {
    if (value == null) return true;
    if (value is String && value.trim().isEmpty) return true;
    if (value is List && value.isEmpty) return true;
    if (value is Map && value.isEmpty) return true;
    return false;
  }
}
