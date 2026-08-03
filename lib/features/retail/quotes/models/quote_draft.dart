// lib/features/retail/quotes/models/quote_draft.dart

import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/quotes/models/quote_line_draft.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/foundation.dart';

import '../../catalog/models/di_sales_tile.dart';
import 'zoho_quote.dart';

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
    this.claimPackId,
    this.lines = const <QuoteLineDraft>[],
    this.currencyCode,
  });

  final ZohoContact? contact;

  /// Zoho customer/contact being billed.
  ///
  /// For direct-pay clinical quotes, this is usually the patient/member contact.
  /// For insurance quotes, this is usually the insurer/payer contact.
  final String? contactId;
  final String? contactName;

  final String? customerNotes;
  final String? reference;

  final QuoteSaleContext saleContext;
  final QuotePaymentContext paymentContext;

  final SalesDocumentAddress? deliveryAddress;

  /// Person receiving care/medicine.
  ///
  /// This is separate from [contactId], which is the payer/customer.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership context.
  ///
  /// Required only for clinical insurance quotes.
  final String? membershipId;

  /// Patient prescription selected for this quote flow.
  ///
  /// Required only for clinical insurance quotes.
  final String? prescriptionId;

  /// Backward-compatible only.
  ///
  /// Claim packs are no longer created or managed at quote stage.
  /// They are created/linked when an insurance quote is converted to invoice.
  final String? claimPackId;

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

  bool get isInsurancePayment =>
      paymentContext == QuotePaymentContext.insurance;

  bool get requiresPatient => saleContext.requiresPatient;

  bool get requiresDeliveryAddress => saleContext.requiresDeliveryAddress;

  bool get requiresMembership {
    return isClinical && paymentContext.requiresMembership;
  }

  bool get requiresPrescription {
    return isClinical && paymentContext.requiresPrescription;
  }

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

  /// Backward-compatible only.
  String? get resolvedClaimPackId {
    final String direct = (claimPackId ?? '').trim();
    return direct.isEmpty ? null : direct;
  }

  bool get hasPatientContext => resolvedPatientId != null;

  bool get hasInsuranceContext => resolvedMembershipId != null;

  bool get hasPrescriptionContext => resolvedPrescriptionId != null;

  /// Backward-compatible only.
  bool get hasClaimPackContext => resolvedClaimPackId != null;

  bool get hasRequiredInsuranceQuoteContext {
    return isClinical &&
        isInsurancePayment &&
        hasPatientContext &&
        hasInsuranceContext &&
        hasPrescriptionContext;
  }

  bool get canCreateQuote {
    if (!hasCustomer || !hasLines) return false;

    if (requiresPatient && !hasPatientContext) return false;

    if (requiresDeliveryAddress && !hasDeliveryAddress) return false;

    if (requiresMembership && !hasInsuranceContext) return false;

    if (requiresPrescription && !hasPrescriptionContext) return false;

    return true;
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
    String? claimPackId,
    bool clearClaimPackId = false,
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
      claimPackId: clearClaimPackId ? null : (claimPackId ?? this.claimPackId),
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
      clearClaimPackId: true,
    );
  }

  QuoteDraft withPatientSnapshot(SalesDocumentPatientSnapshot snapshot) {
    final bool patientChanged =
        resolvedPatientId != null && resolvedPatientId != snapshot.patientId;

    return copyWith(
      patientId: snapshot.patientId,
      patientSnapshot: snapshot,
      membershipId: snapshot.membershipId,
      saleContext: QuoteSaleContext.clinical,
      paymentContext: paymentContext,
      clearPrescriptionId: patientChanged,
      clearClaimPackId: patientChanged,
    );
  }

  QuoteDraft withPrescriptionId(String? prescriptionId) {
    final String clean = (prescriptionId ?? '').trim();

    return copyWith(
      prescriptionId: clean.isEmpty ? null : clean,
      clearPrescriptionId: clean.isEmpty,
      clearClaimPackId: true,
    );
  }

  /// Backward-compatible only.
  ///
  /// New quote creation should not select/manage claim packs.
  QuoteDraft withClaimPackId(String? claimPackId) {
    final String clean = (claimPackId ?? '').trim();

    return copyWith(
      claimPackId: clean.isEmpty ? null : clean,
      clearClaimPackId: clean.isEmpty,
    );
  }

  QuoteDraft withInsurancePayment() {
    return copyWith(
      saleContext: QuoteSaleContext.clinical,
      paymentContext: QuotePaymentContext.insurance,
    );
  }

  QuoteDraft withDirectPayment() {
    return copyWith(
      paymentContext: QuotePaymentContext.directPay,
      clearClaimPackId: true,
    );
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
      claimPackId: quote.resolvedClaimPackId,
      currencyCode: quote.currencyCode,
      lines: hydratedLines,
    );
  }
}
