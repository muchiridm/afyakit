// lib/features/retail/quotes/controllers/states/quote_meta_state.dart

import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/foundation.dart';

@immutable
class QuoteMetaState {
  const QuoteMetaState({
    this.editingQuoteId,
    this.contact,
    this.reference,
    this.customerNotes,
    this.purchaseContext = QuotePurchaseContext.privateUse,
    this.paymentContext = QuotePaymentContext.directPay,
    this.fulfilmentMethod = QuoteFulfilmentMethod.delivery,
    this.quoteDate,
    this.expiryDate,
    this.deliveryAddress,
    this.patientSnapshot,
    this.membershipId,
    this.prescriptionId,
    this.prescriptionLabel,
  });

  final String? editingQuoteId;
  final ZohoContact? contact;
  final String? reference;
  final String? customerNotes;

  /// privateUse:
  ///   A patient-linked quote for personal use.
  ///
  /// company:
  ///   A company or organisation quote. Patient context is optional.
  final QuotePurchaseContext purchaseContext;

  /// directPay:
  ///   The selected Zoho customer/contact pays directly.
  ///   This includes patient self-pay, parent/guardian paying,
  ///   employer/company direct-pay, OTC, and B2B.
  ///
  /// insurance:
  ///   The insurer is billed. Requires private use, membership,
  ///   and a prescription.
  final QuotePaymentContext paymentContext;
  final QuoteFulfilmentMethod fulfilmentMethod;

  /// Zoho: `date` / `estimate_date`.
  final DateTime? quoteDate;

  /// Zoho: `expiry_date`.
  final DateTime? expiryDate;

  final SalesDocumentAddress? deliveryAddress;

  /// Person receiving care/medicine.
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership used later for quote → invoice → claim.
  final String? membershipId;

  /// Patient prescription used later for quote → invoice → claim.
  ///
  /// Claims require this when create_insurance_claim is true.
  final String? prescriptionId;

  /// UI display label only. Source of truth remains [prescriptionId].
  final String? prescriptionLabel;

  bool get isEditing => _clean(editingQuoteId) != null;

  bool get isPrivateUse => purchaseContext.isPrivateUse;

  bool get isCompany => purchaseContext.isCompany;

  bool get isDirectPay =>
      effectivePaymentContext == QuotePaymentContext.directPay;

  bool get isInsurancePayment {
    return effectivePaymentContext == QuotePaymentContext.insurance;
  }

  /// Company quotes cannot use insurance in the current model.
  QuotePaymentContext get effectivePaymentContext {
    return isCompany ? QuotePaymentContext.directPay : paymentContext;
  }

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

  String get customerIdResolved => (contact?.contactId ?? '').trim();

  String get displayContactName {
    final String? title = _clean(contact?.title);
    return title ?? 'Customer';
  }

  String? get resolvedPatientId => _clean(patientSnapshot?.patientId);

  String? get resolvedMembershipId {
    return _clean(membershipId) ?? _clean(patientSnapshot?.membershipId);
  }

  String? get resolvedPrescriptionId => _clean(prescriptionId);

  bool get hasPatientContext => resolvedPatientId != null;

  bool get hasInsuranceContext => resolvedMembershipId != null;

  bool get hasPrescriptionContext => resolvedPrescriptionId != null;

  bool get hasDeliveryAddress => deliveryAddress?.isUsable == true;

  bool get hasQuoteDate => quoteDate != null;

  bool get canCreateInsuranceClaim {
    return isPrivateUse &&
        isInsurancePayment &&
        hasInsuranceContext &&
        hasPrescriptionContext;
  }

  String get patientLabel {
    return _clean(patientSnapshot?.fullName) ??
        _clean(patientSnapshot?.patientNo) ??
        _clean(patientSnapshot?.patientId) ??
        'Patient';
  }

  String? get patientSubtitle {
    final SalesDocumentPatientSnapshot? patient = patientSnapshot;
    if (patient == null) return null;

    return _joinParts(<String>[
      if (_clean(patient.patientNo) != null) patient.patientNo!.trim(),
      if (_clean(patient.dob) != null) 'DOB ${patient.dob!.trim()}',
      if (_clean(patient.gender) != null) patient.gender!.trim(),
      if (_clean(patient.relationship) != null) patient.relationship!.trim(),
    ]);
  }

  String? get insuranceSubtitle {
    final SalesDocumentPatientSnapshot? patient = patientSnapshot;
    if (patient == null) return null;

    return _joinParts(<String>[
      if (_clean(patient.payerName) != null) patient.payerName!.trim(),
      if (_clean(patient.memberNo) != null)
        'Member ${patient.memberNo!.trim()}',
      if (_clean(patient.scheme) != null) patient.scheme!.trim(),
    ]);
  }

  String? get prescriptionSubtitle {
    if (resolvedPrescriptionId == null) return null;

    return _joinParts(<String>[
      if (_clean(prescriptionLabel) != null) prescriptionLabel!.trim(),
      if (_clean(prescriptionLabel) == null) resolvedPrescriptionId!,
    ]);
  }

  String? get paymentSubtitle {
    if (isCompany) return 'Company · Direct pay';

    if (isInsurancePayment) {
      return _joinParts(<String>[
        'Insurance',
        if (resolvedMembershipId != null) 'membership selected',
        if (resolvedPrescriptionId != null) 'prescription selected',
      ]);
    }

    return 'Direct pay';
  }

  QuoteMetaState copyWith({
    String? editingQuoteId,
    bool clearEditingQuoteId = false,
    ZohoContact? contact,
    bool clearContact = false,
    String? reference,
    bool clearReference = false,
    String? customerNotes,
    bool clearCustomerNotes = false,
    QuotePurchaseContext? purchaseContext,
    QuotePaymentContext? paymentContext,
    QuoteFulfilmentMethod? fulfilmentMethod,
    DateTime? quoteDate,
    bool clearQuoteDate = false,
    DateTime? expiryDate,
    bool clearExpiryDate = false,
    SalesDocumentAddress? deliveryAddress,
    bool clearDeliveryAddress = false,
    SalesDocumentPatientSnapshot? patientSnapshot,
    bool clearPatientSnapshot = false,
    String? membershipId,
    bool clearMembershipId = false,
    String? prescriptionId,
    bool clearPrescriptionId = false,
    String? prescriptionLabel,
    bool clearPrescriptionLabel = false,
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

    final bool clearPrivateUseContext = nextPurchaseContext.isCompany;

    final SalesDocumentPatientSnapshot? nextPatientSnapshot =
        clearPrivateUseContext || clearPatientSnapshot
        ? null
        : (patientSnapshot ?? this.patientSnapshot);

    final String? nextMembershipId =
        clearPrivateUseContext ||
            nextPaymentContext.isDirectPay ||
            clearMembershipId
        ? null
        : (membershipId ?? this.membershipId);

    final String? nextPrescriptionId =
        clearPrivateUseContext || clearPrescriptionId
        ? null
        : (prescriptionId ?? this.prescriptionId);

    final String? nextPrescriptionLabel =
        clearPrivateUseContext ||
            clearPrescriptionLabel ||
            nextPrescriptionId == null
        ? null
        : (prescriptionLabel ?? this.prescriptionLabel);

    return QuoteMetaState(
      editingQuoteId: clearEditingQuoteId
          ? null
          : (editingQuoteId ?? this.editingQuoteId),
      contact: clearContact ? null : (contact ?? this.contact),
      reference: clearReference ? null : (reference ?? this.reference),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
      purchaseContext: nextPurchaseContext,
      paymentContext: nextPaymentContext,
      fulfilmentMethod: nextFulfilmentMethod,
      quoteDate: clearQuoteDate
          ? null
          : normalizeDate(quoteDate ?? this.quoteDate),
      expiryDate: clearExpiryDate
          ? null
          : normalizeDate(expiryDate ?? this.expiryDate),
      deliveryAddress: nextDeliveryAddress,
      patientSnapshot: nextPatientSnapshot,
      membershipId: nextMembershipId,
      prescriptionId: nextPrescriptionId,
      prescriptionLabel: nextPrescriptionLabel,
    );
  }

  static DateTime? normalizeDate(DateTime? date) {
    if (date == null) return null;
    return DateTime(date.year, date.month, date.day);
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }

  static String? _joinParts(List<String> values) {
    final String text = values
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' · ')
        .trim();

    return text.isEmpty ? null : text;
  }
}
