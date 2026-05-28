// lib/features/retail/quotes/models/quote_draft.dart

import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/foundation.dart';

import '../../catalog/models/di_sales_tile.dart';
import 'zoho_quote.dart';

@immutable
class QuoteLineDraft {
  const QuoteLineDraft({
    required this.tile,
    required this.quantity,
    required this.rate,
    this.description,
    this.lineItemId,
    this.zohoItemId,
    this.unit,
  });

  final DiSalesTile tile;
  final int quantity;
  final num rate;

  final String? description;
  final String? lineItemId;
  final String? zohoItemId;
  final String? unit;

  String get key {
    final String id = (lineItemId ?? '').trim();
    if (id.isNotEmpty) return id;

    final String canonKey = tile.canonKey.trim();
    if (canonKey.isNotEmpty) return canonKey;

    final String groupKey = tile.groupKey.trim();
    if (groupKey.isNotEmpty) return groupKey;

    final String title = tile.tileTitle.trim();
    return title.isNotEmpty ? title : 'line';
  }

  int get safeQty {
    if (quantity < 0) return 0;
    if (quantity > 9999) return 9999;
    return quantity;
  }

  num get safeRate {
    if (rate.isNaN || rate.isInfinite || rate < 0) return 0;
    return rate;
  }

  num get amount => safeRate * safeQty;

  QuoteLineDraft copyWith({
    DiSalesTile? tile,
    int? quantity,
    num? rate,
    String? description,
    bool clearDescription = false,
    String? lineItemId,
    bool clearLineItemId = false,
    String? zohoItemId,
    bool clearZohoItemId = false,
    String? unit,
    bool clearUnit = false,
  }) {
    return QuoteLineDraft(
      tile: tile ?? this.tile,
      quantity: quantity ?? this.quantity,
      rate: rate ?? this.rate,
      description: clearDescription ? null : (description ?? this.description),
      lineItemId: clearLineItemId ? null : (lineItemId ?? this.lineItemId),
      zohoItemId: clearZohoItemId ? null : (zohoItemId ?? this.zohoItemId),
      unit: clearUnit ? null : (unit ?? this.unit),
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
    this.saleContext = QuoteSaleContext.clinical,
    this.paymentContext = QuotePaymentContext.directPay,
    this.deliveryAddress,
    this.patientId,
    this.patientSnapshot,
    this.membershipId,
    this.prescriptionId,
    this.lines = const <QuoteLineDraft>[],
    this.currencyCode,
  });

  final ZohoContact? contact;

  /// Zoho customer/contact being billed.
  ///
  /// This may be:
  /// - the patient,
  /// - a parent/guardian/contact paying for the patient,
  /// - a company/employer,
  /// - an insurer,
  /// - an OTC/B2B customer.
  final String? contactId;
  final String? contactName;

  final String? customerNotes;
  final String? reference;

  /// clinical:
  ///   Patient-linked quote. Requires patient + delivery address.
  ///
  /// general:
  ///   OTC / B2B / walk-in / institutional quote. Patient and delivery optional.
  final QuoteSaleContext saleContext;

  /// directPay:
  ///   The selected Zoho customer/contact pays directly.
  ///   This includes patient self-pay, parent paying for child,
  ///   employer/company direct-pay, OTC, and B2B.
  ///
  /// insurance:
  ///   Insurance payer is being billed and a membership is required
  ///   before claim creation.
  final QuotePaymentContext paymentContext;

  final SalesDocumentAddress? deliveryAddress;

  /// Person receiving care/medicine.
  ///
  /// This is separate from the Zoho customer/contact being billed.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership context.
  ///
  /// Only required when [paymentContext] is insurance.
  final String? membershipId;

  /// Patient prescription selected for this quote/claim flow.
  ///
  /// Required before creating an insurance claim.
  final String? prescriptionId;

  final String? currencyCode;

  final List<QuoteLineDraft> lines;

  String get customerIdResolved {
    return (contactId ?? contact?.contactId ?? '').trim();
  }

  bool get hasCustomer => customerIdResolved.isNotEmpty;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get hasLines {
    return lines.any((QuoteLineDraft line) => line.safeQty > 0);
  }

  bool get isClinical => saleContext == QuoteSaleContext.clinical;

  bool get isGeneral => saleContext == QuoteSaleContext.general;

  bool get isDirectPay => paymentContext == QuotePaymentContext.directPay;

  bool get isInsurancePayment {
    return paymentContext == QuotePaymentContext.insurance;
  }

  bool get requiresPatient => saleContext.requiresPatient;

  bool get requiresDeliveryAddress => saleContext.requiresDeliveryAddress;

  bool get requiresMembership {
    return isClinical && paymentContext.requiresMembership;
  }

  bool get requiresPrescription {
    return isClinical && isInsurancePayment;
  }

  /// General sales cannot be insurance claims in the current model.
  QuotePaymentContext get effectivePaymentContext {
    return isGeneral ? QuotePaymentContext.directPay : paymentContext;
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

  String? get resolvedPrescriptionId {
    final String direct = (prescriptionId ?? '').trim();
    return direct.isEmpty ? null : direct;
  }

  bool get hasPatientContext => resolvedPatientId != null;

  bool get hasInsuranceContext => resolvedMembershipId != null;

  bool get hasPrescriptionContext => resolvedPrescriptionId != null;

  bool get canCreateQuote {
    if (!hasCustomer || !hasLines) return false;

    if (requiresPatient && !hasPatientContext) return false;

    if (requiresDeliveryAddress && !hasDeliveryAddress) return false;

    if (requiresMembership && !hasInsuranceContext) return false;

    return true;
  }

  bool get canCreateInsuranceClaim {
    return isClinical &&
        isInsurancePayment &&
        hasInsuranceContext &&
        hasPrescriptionContext;
  }

  num get total {
    return lines.fold<num>(0, (num sum, QuoteLineDraft line) {
      return sum + line.amount;
    });
  }

  String get displayContactName {
    final String displayName = (contact?.displayName ?? '').trim();
    if (displayName.isNotEmpty) return displayName;

    final String fallbackName = (contactName ?? '').trim();
    if (fallbackName.isNotEmpty) return fallbackName;

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
    bool clearCustomerNotes = false,
    String? reference,
    bool clearReference = false,
    QuoteSaleContext? saleContext,
    QuotePaymentContext? paymentContext,
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
    List<QuoteLineDraft>? lines,
    bool clearLines = false,
    String? currencyCode,
    bool clearCurrencyCode = false,
  }) {
    final QuoteSaleContext nextSaleContext = saleContext ?? this.saleContext;

    final QuotePaymentContext nextPaymentContext =
        nextSaleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : (paymentContext ?? this.paymentContext);

    return QuoteDraft(
      contact: clearContact ? null : (contact ?? this.contact),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      contactName: clearContactName ? null : (contactName ?? this.contactName),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
      reference: clearReference ? null : (reference ?? this.reference),
      saleContext: nextSaleContext,
      paymentContext: nextPaymentContext,
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
      prescriptionId: clearPrescriptionId
          ? null
          : (prescriptionId ?? this.prescriptionId),
      lines: clearLines ? const <QuoteLineDraft>[] : (lines ?? this.lines),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
    );
  }

  QuoteDraft upsertLine(QuoteLineDraft next) {
    final String nextKey = next.key;
    final int idx = lines.indexWhere((QuoteLineDraft line) {
      return line.key == nextKey;
    });

    if (next.safeQty == 0) {
      if (idx < 0) return this;

      final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
        ..removeAt(idx);

      return copyWith(lines: copy);
    }

    if (idx < 0) {
      final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
        ..add(next);

      return copyWith(lines: copy);
    }

    final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
      ..[idx] = next;

    return copyWith(lines: copy);
  }

  QuoteDraft removeLineByKey(String key) {
    final String cleanKey = key.trim();
    if (cleanKey.isEmpty) return this;

    final int idx = lines.indexWhere((QuoteLineDraft line) {
      return line.key == cleanKey;
    });

    if (idx < 0) return this;

    final List<QuoteLineDraft> copy = List<QuoteLineDraft>.from(lines)
      ..removeAt(idx);

    return copyWith(lines: copy);
  }

  QuoteDraft clearCustomer() {
    return copyWith(
      clearContact: true,
      clearContactId: true,
      clearContactName: true,
    );
  }

  QuoteDraft clearPatientContext() {
    return copyWith(
      clearPatientId: true,
      clearPatientSnapshot: true,
      clearMembershipId: true,
      clearPrescriptionId: true,
    );
  }

  QuoteDraft withPatientSnapshot(SalesDocumentPatientSnapshot snapshot) {
    return copyWith(
      patientId: snapshot.patientId,
      patientSnapshot: snapshot,
      membershipId: snapshot.membershipId,
      saleContext: QuoteSaleContext.clinical,
      // Important:
      // Do not auto-switch to insurance just because membership exists.
      // Parent/self/company direct-pay can still involve a patient with insurance.
      paymentContext: paymentContext,
      clearPrescriptionId:
          resolvedPatientId != null && resolvedPatientId != snapshot.patientId,
    );
  }

  QuoteDraft withPrescriptionId(String? prescriptionId) {
    final String clean = (prescriptionId ?? '').trim();

    return copyWith(
      prescriptionId: clean.isEmpty ? null : clean,
      clearPrescriptionId: clean.isEmpty,
    );
  }

  QuoteDraft withInsurancePayment() {
    return copyWith(
      saleContext: QuoteSaleContext.clinical,
      paymentContext: QuotePaymentContext.insurance,
    );
  }

  QuoteDraft withDirectPayment() {
    return copyWith(paymentContext: QuotePaymentContext.directPay);
  }

  factory QuoteDraft.fromZohoQuote(ZohoQuote quote) {
    final List<QuoteLineDraft> hydratedLines = quote.lineItems
        .map((ZohoQuoteLineItem line) {
          final String stableKey = (line.lineItemId ?? '').trim();

          final DiSalesTile tile = stableKey.isNotEmpty
              ? DiSalesTile.fallbackFromName(
                  name: line.name,
                  description: line.description,
                  canonKey: stableKey,
                  groupKey: stableKey,
                )
              : DiSalesTile.fallbackFromName(
                  name: line.name,
                  description: line.description,
                );

          return QuoteLineDraft(
            tile: tile,
            quantity: line.quantity.round(),
            rate: line.rate,
            description: (line.description ?? '').trim().isEmpty
                ? null
                : line.description,
            lineItemId: stableKey.isEmpty ? null : stableKey,
            zohoItemId: null,
            unit: (line.unit ?? '').trim().isEmpty ? null : line.unit,
          );
        })
        .toList(growable: false);

    return QuoteDraft(
      contactId: (quote.customerId ?? '').trim().isEmpty
          ? null
          : quote.customerId,
      contactName: quote.customerName.trim().isEmpty
          ? null
          : quote.customerName.trim(),
      customerNotes: quote.notes,
      reference: quote.accountNumber,
      saleContext: quote.saleContext,
      paymentContext: quote.paymentContext,
      deliveryAddress: quote.deliveryAddress,
      patientId: quote.resolvedPatientId,
      patientSnapshot: quote.patientSnapshot,
      membershipId: quote.resolvedMembershipId,
      prescriptionId: quote.resolvedPrescriptionId,
      currencyCode: quote.currencyCode,
      lines: hydratedLines,
    );
  }
}
