// lib/features/retail/quotes/models/zoho_quote.dart

import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
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
    this.purchaseContext = QuotePurchaseContext.privateUse,
    this.paymentContext = QuotePaymentContext.directPay,
    this.fulfilmentMethod = QuoteFulfilmentMethod.delivery,
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
    this.prescriptionId,
    this.claimPackId,
    this.lineItems = const <ZohoQuoteLineItem>[],
  });

  final String quoteId;
  final String customerName;
  final String status;

  final DateTime? date;
  final DateTime? expiryDate;

  final num total;

  final QuotePurchaseContext purchaseContext;
  final QuotePaymentContext paymentContext;
  final QuoteFulfilmentMethod fulfilmentMethod;

  final String? accountNumber;

  final String? currencyCode;
  final String? customerId;
  final String? notes;
  final String? terms;

  final SalesDocumentAddress? deliveryAddress;

  /// Patient receiving care or medicine.
  ///
  /// This is separate from [customerId], which identifies the payer/customer.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership, meaningful only for insurance payment.
  final String? membershipId;

  /// Patient prescription linked to this quote.
  final String? prescriptionId;

  /// Backward-compatible only.
  ///
  /// Claim packs are created or linked when an insurance quote is converted
  /// to an invoice, not while creating the quote.
  final String? claimPackId;

  final List<ZohoQuoteLineItem> lineItems;

  bool get isPrivateUse => purchaseContext.isPrivateUse;

  bool get isCompany => purchaseContext.isCompany;

  QuotePaymentContext get effectivePaymentContext {
    return isCompany ? QuotePaymentContext.directPay : paymentContext;
  }

  bool get isDirectPay => effectivePaymentContext.isDirectPay;

  bool get isInsurancePayment => effectivePaymentContext.isInsurance;

  bool get isDelivery => fulfilmentMethod.isDelivery;

  bool get isPickup => fulfilmentMethod.isPickup;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get hasFulfilmentContext {
    return isPickup || hasDeliveryAddress;
  }

  bool get hasPatientContext {
    final String direct = (patientId ?? '').trim();
    final String snapshotId = (patientSnapshot?.patientId ?? '').trim();

    return direct.isNotEmpty || snapshotId.isNotEmpty;
  }

  bool get hasInsuranceContext {
    final String direct = (membershipId ?? '').trim();
    final String snapshotId = (patientSnapshot?.membershipId ?? '').trim();

    return direct.isNotEmpty || snapshotId.isNotEmpty;
  }

  bool get hasPrescriptionContext {
    return resolvedPrescriptionId != null;
  }

  /// Backward-compatible only.
  bool get hasClaimPackContext {
    return resolvedClaimPackId != null;
  }

  bool get hasRequiredInsuranceQuoteContext {
    return isPrivateUse &&
        isInsurancePayment &&
        hasPatientContext &&
        hasInsuranceContext &&
        hasPrescriptionContext;
  }

  String? get resolvedPatientId {
    final String direct = (patientId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final String snapshotId = (patientSnapshot?.patientId ?? '').trim();
    return snapshotId.isEmpty ? null : snapshotId;
  }

  String? get resolvedMembershipId {
    final String direct = (membershipId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final String snapshotId = (patientSnapshot?.membershipId ?? '').trim();
    return snapshotId.isEmpty ? null : snapshotId;
  }

  String? get resolvedPrescriptionId {
    final String direct = (prescriptionId ?? '').trim();
    return direct.isEmpty ? null : direct;
  }

  /// Backward-compatible only.
  String? get resolvedClaimPackId {
    final String direct = (claimPackId ?? '').trim();
    return direct.isEmpty ? null : direct;
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

    final QuotePurchaseContext purchaseContext = QuotePurchaseContext.fromApi(
      json['sale_context'] ??
          json['saleContext'] ??
          json['purchase_context'] ??
          json['purchaseContext'],
    );

    final QuotePaymentContext paymentContext = purchaseContext.isCompany
        ? QuotePaymentContext.directPay
        : QuotePaymentContext.fromApi(
            json['payment_context'] ?? json['paymentContext'],
          );

    final SalesDocumentAddress? parsedDeliveryAddress = _parseDeliveryAddress(
      json['delivery_address'] ??
          json['deliveryAddress'] ??
          json['shipping_address'],
    );

    final Object? rawFulfilment =
        json['fulfilment_method'] ??
        json['fulfilmentMethod'] ??
        json['fulfillment_method'] ??
        json['fulfillmentMethod'];

    final QuoteFulfilmentMethod fulfilmentMethod = rawFulfilment == null
        ? QuoteFulfilmentMethod.delivery
        : QuoteFulfilmentMethod.fromApi(rawFulfilment);

    final SalesDocumentAddress? deliveryAddress = fulfilmentMethod.isDelivery
        ? parsedDeliveryAddress
        : null;

    final String? accountNumber = _asCleanOrNull(
      json['account_number'] ??
          json['accountNumber'] ??
          json['reference_number'],
    );

    final String? currencyCode = _asCleanOrNull(
      json['currency_code'] ?? json['currencyCode'],
    );

    final String? customerId = _asCleanOrNull(
      json['customer_id'] ?? json['customerId'],
    );

    final String? notes = _asCleanOrNull(json['notes']);
    final String? terms = _asCleanOrNull(json['terms']);

    final SalesDocumentPatientSnapshot? patientSnapshot = _parsePatientSnapshot(
      json['patient_snapshot'] ?? json['patientSnapshot'],
    );

    final String? patientId =
        _asCleanOrNull(json['patient_id'] ?? json['patientId']) ??
        patientSnapshot?.patientId;

    final String? membershipId =
        _asCleanOrNull(json['membership_id'] ?? json['membershipId']) ??
        patientSnapshot?.membershipId;

    final String? prescriptionId = _asCleanOrNull(
      json['prescription_id'] ?? json['prescriptionId'],
    );

    final String? claimPackId = _asCleanOrNull(
      json['claim_pack_id'] ?? json['claimPackId'],
    );

    final Object? rawLines = json['line_items'] ?? json['lineItems'];

    final List<ZohoQuoteLineItem> lines = <ZohoQuoteLineItem>[];

    if (rawLines is List) {
      for (final Object? item in rawLines) {
        if (item is Map<String, dynamic>) {
          lines.add(ZohoQuoteLineItem.fromJson(item));
          continue;
        }

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
      purchaseContext: purchaseContext,
      paymentContext: paymentContext,
      fulfilmentMethod: fulfilmentMethod,
      accountNumber: accountNumber,
      currencyCode: currencyCode,
      customerId: customerId,
      notes: notes,
      terms: terms,
      deliveryAddress: deliveryAddress,
      patientId: patientId,
      patientSnapshot: patientSnapshot,
      membershipId: membershipId,
      prescriptionId: prescriptionId,
      claimPackId: claimPackId,
      lineItems: lines,
    );
  }

  JsonMap toJson() {
    final QuotePaymentContext safePaymentContext = purchaseContext.isCompany
        ? QuotePaymentContext.directPay
        : paymentContext;

    final SalesDocumentAddress? safeDeliveryAddress =
        fulfilmentMethod.isDelivery ? deliveryAddress : null;

    return <String, dynamic>{
      'estimate_id': quoteId,
      'customer_name': customerName,
      'status': status,
      'date': date?.toIso8601String(),
      'expiry_date': expiryDate?.toIso8601String(),
      'total': total,

      // Retain the existing backend field and values.
      'sale_context': purchaseContext.apiValue,
      'payment_context': safePaymentContext.apiValue,

      'fulfilment_method': fulfilmentMethod.apiValue,

      'account_number': accountNumber,
      'currency_code': currencyCode,
      'customer_id': customerId,
      'notes': notes,
      'terms': terms,

      if (safeDeliveryAddress != null)
        'delivery_address': safeDeliveryAddress.toJson(),

      'patient_id': patientId,
      'patient_snapshot': patientSnapshot?.toJson(),
      'membership_id': membershipId,
      'prescription_id': prescriptionId,
      'claim_pack_id': claimPackId,
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
    bool clearDate = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    num? total,
    QuotePurchaseContext? purchaseContext,
    QuotePaymentContext? paymentContext,
    QuoteFulfilmentMethod? fulfilmentMethod,
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
    String? prescriptionId,
    bool clearPrescriptionId = false,
    String? claimPackId,
    bool clearClaimPackId = false,
    List<ZohoQuoteLineItem>? lineItems,
  }) {
    final QuotePurchaseContext nextPurchaseContext =
        purchaseContext ?? this.purchaseContext;

    final QuotePaymentContext nextPaymentContext = nextPurchaseContext.isCompany
        ? QuotePaymentContext.directPay
        : (paymentContext ?? this.paymentContext);

    final QuoteFulfilmentMethod nextFulfilmentMethod =
        fulfilmentMethod ?? this.fulfilmentMethod;

    final SalesDocumentAddress? nextDeliveryAddress =
        nextFulfilmentMethod.isPickup || clearDeliveryAddress
        ? null
        : (deliveryAddress ?? this.deliveryAddress);

    return ZohoQuote(
      quoteId: quoteId ?? this.quoteId,
      customerName: customerName ?? this.customerName,
      status: status ?? this.status,
      date: clearDate ? null : (date ?? this.date),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      total: total ?? this.total,
      purchaseContext: nextPurchaseContext,
      paymentContext: nextPaymentContext,
      fulfilmentMethod: nextFulfilmentMethod,
      accountNumber: clearAccountNumber
          ? null
          : (accountNumber ?? this.accountNumber),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
      customerId: clearCustomerId ? null : (customerId ?? this.customerId),
      notes: clearNotes ? null : (notes ?? this.notes),
      terms: clearTerms ? null : (terms ?? this.terms),
      deliveryAddress: nextDeliveryAddress,
      patientId: clearPatientId ? null : (patientId ?? this.patientId),
      patientSnapshot: clearPatientSnapshot
          ? null
          : (patientSnapshot ?? this.patientSnapshot),
      membershipId: clearMembershipId
          ? null
          : (membershipId ?? this.membershipId),
      prescriptionId: clearPrescriptionId
          ? null
          : (prescriptionId ?? this.prescriptionId),
      claimPackId: clearClaimPackId ? null : (claimPackId ?? this.claimPackId),
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
