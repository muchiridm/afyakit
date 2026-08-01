// lib/features/retail/quotes/models/quote_draft.dart

import 'package:afyakit/features/retail/catalog/models/di_sales_tile.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/quotes/models/quote_line_draft.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote.dart';
import 'package:afyakit/features/retail/quotes/models/zoho_quote_line_item.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/foundation.dart';

@immutable
class QuoteDraft {
  const QuoteDraft({
    this.contact,
    this.contactId,
    this.contactName,
    this.customerNotes,
    this.reference,
    this.purchaseContext = QuotePurchaseContext.privateUse,
    this.paymentContext = QuotePaymentContext.directPay,
    this.fulfilmentMethod = QuoteFulfilmentMethod.delivery,
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
  /// For direct-pay private-use quotes, this is usually the member/customer.
  /// For insurance quotes, this is normally the insurer/payer contact.
  final String? contactId;
  final String? contactName;

  final String? customerNotes;
  final String? reference;

  final QuotePurchaseContext purchaseContext;
  final QuotePaymentContext paymentContext;
  final QuoteFulfilmentMethod fulfilmentMethod;

  final SalesDocumentAddress? deliveryAddress;

  /// Person receiving care or medicine.
  ///
  /// This remains separate from [contactId], which identifies the payer.
  final String? patientId;
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership context.
  ///
  /// Required only for private-use insurance quotes.
  final String? membershipId;

  /// Patient prescription selected for this quote.
  ///
  /// Required for insurance and optional for direct pay.
  final String? prescriptionId;

  /// Backward-compatible only.
  ///
  /// Claim packs are no longer created or managed at quote stage.
  /// They are created or linked when an insurance quote becomes an invoice.
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

  bool get isPrivateUse => purchaseContext.isPrivateUse;

  bool get isCompany => purchaseContext.isCompany;

  QuotePaymentContext get effectivePaymentContext {
    return isCompany ? QuotePaymentContext.directPay : paymentContext;
  }

  bool get isDirectPay => effectivePaymentContext.isDirectPay;

  bool get isInsurancePayment => effectivePaymentContext.isInsurance;

  bool get requiresPatient => purchaseContext.requiresPatient;

  bool get requiresDeliveryLocation => fulfilmentMethod.requiresLocation;

  bool get hasFulfilmentContext {
    return fulfilmentMethod.isPickup || hasDeliveryAddress;
  }

  bool get requiresMembership {
    return isPrivateUse && effectivePaymentContext.requiresMembership;
  }

  bool get requiresPrescription {
    return isPrivateUse && effectivePaymentContext.requiresPrescription;
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

  bool get hasPatientContext => resolvedPatientId != null;

  bool get hasInsuranceContext => resolvedMembershipId != null;

  bool get hasPrescriptionContext => resolvedPrescriptionId != null;

  /// Backward-compatible only.
  bool get hasClaimPackContext => resolvedClaimPackId != null;

  bool get hasRequiredInsuranceQuoteContext {
    return isPrivateUse &&
        isInsurancePayment &&
        hasPatientContext &&
        hasInsuranceContext &&
        hasPrescriptionContext;
  }

  bool get canCreateQuote {
    if (!hasCustomer || !hasLines) return false;

    if (requiresPatient && !hasPatientContext) return false;

    if (!hasFulfilmentContext) return false;

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
    QuotePurchaseContext? purchaseContext,
    QuotePaymentContext? paymentContext,
    QuoteFulfilmentMethod? fulfilmentMethod,
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

    return QuoteDraft(
      contact: clearContact ? null : (contact ?? this.contact),
      contactId: clearContactId ? null : (contactId ?? this.contactId),
      contactName: clearContactName ? null : (contactName ?? this.contactName),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
      reference: clearReference ? null : (reference ?? this.reference),
      purchaseContext: nextPurchaseContext,
      paymentContext: nextPaymentContext,
      fulfilmentMethod: nextFulfilmentMethod,
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
      lines: clearLines ? const <QuoteLineDraft>[] : (lines ?? this.lines),
      currencyCode: clearCurrencyCode
          ? null
          : (currencyCode ?? this.currencyCode),
    );
  }

  QuoteDraft upsertLine(QuoteLineDraft next) {
    final String nextKey = next.key;

    final int index = lines.indexWhere((QuoteLineDraft line) {
      return line.key == nextKey;
    });

    if (next.safeQty == 0) {
      if (index < 0) return this;

      final List<QuoteLineDraft> updated = List<QuoteLineDraft>.from(lines)
        ..removeAt(index);

      return copyWith(lines: updated);
    }

    if (index < 0) {
      final List<QuoteLineDraft> updated = List<QuoteLineDraft>.from(lines)
        ..add(next);

      return copyWith(lines: updated);
    }

    final List<QuoteLineDraft> updated = List<QuoteLineDraft>.from(lines)
      ..[index] = next;

    return copyWith(lines: updated);
  }

  QuoteDraft removeLineByKey(String key) {
    final String cleanKey = key.trim();
    if (cleanKey.isEmpty) return this;

    final int index = lines.indexWhere((QuoteLineDraft line) {
      return line.key == cleanKey;
    });

    if (index < 0) return this;

    final List<QuoteLineDraft> updated = List<QuoteLineDraft>.from(lines)
      ..removeAt(index);

    return copyWith(lines: updated);
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
      purchaseContext: QuotePurchaseContext.privateUse,
      paymentContext: effectivePaymentContext,
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
  /// New quote creation should not select or manage claim packs.
  QuoteDraft withClaimPackId(String? claimPackId) {
    final String clean = (claimPackId ?? '').trim();

    return copyWith(
      claimPackId: clean.isEmpty ? null : clean,
      clearClaimPackId: clean.isEmpty,
    );
  }

  QuoteDraft withInsurancePayment() {
    return copyWith(
      purchaseContext: QuotePurchaseContext.privateUse,
      paymentContext: QuotePaymentContext.insurance,
    );
  }

  QuoteDraft withDirectPayment() {
    return copyWith(
      paymentContext: QuotePaymentContext.directPay,
      clearMembershipId: true,
      clearClaimPackId: true,
    );
  }

  QuoteDraft withFulfilmentMethod(QuoteFulfilmentMethod method) {
    return copyWith(
      fulfilmentMethod: method,
      clearDeliveryAddress: method.isPickup,
    );
  }

  QuoteDraft withDeliveryAddress(SalesDocumentAddress address) {
    return copyWith(
      fulfilmentMethod: QuoteFulfilmentMethod.delivery,
      deliveryAddress: address,
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
      purchaseContext: quote.purchaseContext,
      paymentContext: quote.paymentContext,
      fulfilmentMethod: quote.fulfilmentMethod,
      deliveryAddress: quote.fulfilmentMethod.isDelivery
          ? quote.deliveryAddress
          : null,
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
