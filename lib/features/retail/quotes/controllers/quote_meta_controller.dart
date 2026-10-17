// lib/features/retail/quotes/controllers/quote_meta_controller.dart
import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/records/native_contacts/native_contact.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteMetaControllerProvider =
    StateNotifierProvider<QuoteMetaController, QuoteMetaState>(
      (Ref ref) => QuoteMetaController(ref),
    );

@immutable
class QuoteMetaState {
  const QuoteMetaState({
    this.editingQuoteId,
    this.contact,
    this.payer,
    this.nativeContactId,
    this.zohoContactId,
    this.mappedCustomerName,
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

  /// Transitional alias for older quote-editor callers. Always a Native Contact.
  /// New code should use [payer] and [setNativePayer].
  final NativeContact? contact;

  /// Canonical payer selected from the Native Contacts directory.
  final NativeContact? payer;

  /// Legacy metadata from an already-loaded accounting document.
  /// These are not evidence of a verified mapping for new selections.
  final String? nativeContactId;
  final String? zohoContactId;
  final String? mappedCustomerName;

  /// Canonical account of the selected payer. Never substitute a Zoho ID.
  String get payerAccountNumber =>
      (payer?.accountNumber ?? contact?.accountNumber ?? '').trim();

  String get accountNumberResolved => payerAccountNumber;

  /// Legacy accounting ID, usable only for an unchanged historical quote.
  String get historicalZohoCustomerId => (zohoContactId ?? '').trim();

  bool get hasCustomerSelection =>
      accountNumberResolved.isNotEmpty ||
      (isEditing && historicalZohoCustomerId.isNotEmpty);
  final String? reference;
  final String? customerNotes;

  /// privateUse:
  ///   A patient-linked quote for personal use.
  ///
  /// company:
  ///   A company or organisation quote. Patient context is optional.
  final QuotePurchaseContext purchaseContext;

  /// directPay:
  ///   The selected Native Contact pays directly.
  ///   This includes patient self-pay, parent/guardian paying,
  ///   employer/company direct-pay, OTC, and B2B.
  ///
  /// insurance:
  ///   The insurer is billed. Requires private use, membership,
  ///   and a prescription.
  final QuotePaymentContext paymentContext;
  final QuoteFulfilmentMethod fulfilmentMethod;

  /// Zoho: \`date\` / \`estimate_date\`.
  final DateTime? quoteDate;

  /// Zoho: \`expiry_date\`.
  final DateTime? expiryDate;
  final SalesDocumentAddress? deliveryAddress;

  /// Person receiving care/medicine in the contextual patient role.
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

  /// Compatibility getter for historical accounting documents only.
  /// New quote submissions must use [accountNumberResolved].
  String get customerIdResolved => historicalZohoCustomerId;

  /// Display name of the selected payer.
  String get displayContactName {
    final String? name =
        _clean(payer?.displayName) ?? _clean(mappedCustomerName);
    if (name != null) return name;
    return _clean(contact?.displayName) ?? 'Customer';
  }

  /// Canonical AfyaKit Health Profile ID for the person in the patient role.
  String? get resolvedProfileId => _clean(patientSnapshot?.profileId);
  String? get resolvedMembershipId {
    return _clean(membershipId) ?? _clean(patientSnapshot?.membershipId);
  }

  String? get resolvedPrescriptionId => _clean(prescriptionId);
  bool get hasPatientContext => resolvedProfileId != null;
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
        _clean(patientSnapshot?.profileId) ??
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
    NativeContact? contact,
    bool clearContact = false,
    NativeContact? payer,
    bool clearPayer = false,
    String? nativeContactId,
    String? zohoContactId,
    String? mappedCustomerName,
    bool clearCustomerMapping = false,
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
      payer: clearPayer ? null : (payer ?? this.payer),
      nativeContactId: clearCustomerMapping
          ? null
          : (nativeContactId ?? this.nativeContactId),
      zohoContactId: clearCustomerMapping
          ? null
          : (zohoContactId ?? this.zohoContactId),
      mappedCustomerName: clearCustomerMapping
          ? null
          : (mappedCustomerName ?? this.mappedCustomerName),
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

class QuoteMetaController extends StateNotifier<QuoteMetaState> {
  QuoteMetaController(this._ref) : super(const QuoteMetaState());
  final Ref _ref;
  QuoteContactPolicy get _policy => _ref.read(quoteContactPolicyProvider);

  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;
  void beginNew() {
    final DateTime quoteDate = state.quoteDate ?? _today();
    final DateTime expiryDate = state.expiryDate ?? _defaultExpiry(quoteDate);
    if (_isMemberScoped) {
      state = state.copyWith(
        clearEditingQuoteId: true,
        quoteDate: quoteDate,
        expiryDate: expiryDate,
      );
      return;
    }
    final bool wasEditing = state.isEditing;
    state = state.copyWith(
      clearEditingQuoteId: true,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
      purchaseContext: wasEditing
          ? QuotePurchaseContext.privateUse
          : state.purchaseContext,
      paymentContext: wasEditing
          ? QuotePaymentContext.directPay
          : state.effectivePaymentContext,
      clearContact: wasEditing,
      clearPayer: wasEditing,
      clearCustomerMapping: wasEditing,
      clearPatientSnapshot: wasEditing,
      clearMembershipId: wasEditing,
      clearPrescriptionId: wasEditing,
      clearPrescriptionLabel: wasEditing,
      clearDeliveryAddress: wasEditing,
    );
  }

  void beginEdit(String quoteId) {
    final String? id = _clean(quoteId);
    state = state.copyWith(editingQuoteId: id, clearEditingQuoteId: id == null);
  }

  void clearAll() {
    state = const QuoteMetaState();
  }

  void setPurchaseContext(QuotePurchaseContext purchaseContext) {
    if (state.purchaseContext == purchaseContext) return;
    final bool isCompany = purchaseContext.isCompany;
    state = state.copyWith(
      purchaseContext: purchaseContext,
      paymentContext: isCompany
          ? QuotePaymentContext.directPay
          : state.effectivePaymentContext,
      clearPatientSnapshot: isCompany,
      clearMembershipId: isCompany,
      clearPrescriptionId: isCompany,
      clearPrescriptionLabel: isCompany,
    );
  }

  void setPaymentContext(QuotePaymentContext paymentContext) {
    if (state.isCompany) return;
    if (state.paymentContext == paymentContext) return;
    final bool isDirectPay = paymentContext.isDirectPay;
    state = state.copyWith(
      purchaseContext: QuotePurchaseContext.privateUse,
      paymentContext: paymentContext,
      clearMembershipId: isDirectPay,
    );
  }

  /// Compatibility method used by older editor call sites.
  void setContact(NativeContact? contact) => setNativePayer(contact);

  /// Sets the canonical payer for new quotation requests.
  /// The corresponding Native -> Zoho mapping is resolved by the API.
  void setNativePayer(NativeContact? payer) {
    if (_isMemberScoped) return;
    if (payer != null && (payer.accountNumber).trim().isEmpty) {
      throw StateError('Selected payer has no Native account number');
    }
    state = state.copyWith(
      payer: payer,
      clearPayer: payer == null,
      clearContact: true,
      clearCustomerMapping: true,
    );
  }

  // Customer mapping is deliberately not resolved or stored in Flutter.
  // App-scoped Native -> Zoho resolution belongs to the API.

  void clearContact() {
    if (_isMemberScoped) return;
    state = state.copyWith(
      clearContact: true,
      clearPayer: true,
      clearCustomerMapping: true,
    );
  }

  void setReference(String value) {
    final String? cleanValue = _clean(value);
    state = state.copyWith(
      reference: cleanValue,
      clearReference: cleanValue == null,
    );
  }

  void setCustomerNotes(String value) {
    final String? cleanValue = _clean(value);
    state = state.copyWith(
      customerNotes: cleanValue,
      clearCustomerNotes: cleanValue == null,
    );
  }

  void setFulfilmentMethod(QuoteFulfilmentMethod method) {
    if (state.fulfilmentMethod == method) return;
    state = state.copyWith(
      fulfilmentMethod: method,
      clearDeliveryAddress: method.isPickup,
    );
  }

  void setDeliveryLocation(SalesDocumentAddress address) {
    state = state.copyWith(
      fulfilmentMethod: QuoteFulfilmentMethod.delivery,
      deliveryAddress: address,
    );
  }

  void setQuoteDate(DateTime date) {
    final DateTime normalized = _normalize(date);
    final DateTime? currentExpiry = state.expiryDate;
    state = state.copyWith(
      quoteDate: normalized,
      expiryDate: currentExpiry == null
          ? _defaultExpiry(normalized)
          : _normalize(currentExpiry),
    );
  }

  void clearQuoteDate() {
    state = state.copyWith(clearQuoteDate: true);
  }

  void setExpiryDate(DateTime date) {
    state = state.copyWith(expiryDate: _normalize(date));
  }

  void clearExpiryDate() {
    state = state.copyWith(clearExpiryDate: true);
  }

  void setDeliveryAddress(SalesDocumentAddress? address) {
    state = state.copyWith(
      deliveryAddress: address,
      clearDeliveryAddress: address == null,
    );
  }

  void clearDeliveryAddress() {
    state = state.copyWith(clearDeliveryAddress: true);
  }

  void setPatientContext({
    required SalesDocumentPatientSnapshot patientSnapshot,
    String? membershipId,
    NativeContact? payerContact,
    QuotePaymentContext paymentContext = QuotePaymentContext.directPay,
  }) {
    final String? resolvedMembershipId = _resolveMembershipId(
      membershipId: membershipId,
      patientSnapshot: patientSnapshot,
    );
    final bool isInsurance = paymentContext == QuotePaymentContext.insurance;
    final NativeContact? insurancePayer = isInsurance
        ? _requiredInsurancePayerContact(payerContact)
        : null;
    final String? previousProfileId = state.resolvedProfileId;
    final String? nextProfileId = _clean(patientSnapshot.profileId);
    final bool patientChanged =
        previousProfileId != null &&
        nextProfileId != null &&
        previousProfileId != nextProfileId;
    state = state.copyWith(
      purchaseContext: QuotePurchaseContext.privateUse,
      paymentContext: isInsurance
          ? QuotePaymentContext.insurance
          : QuotePaymentContext.directPay,
      payer: insurancePayer,
      clearPayer: !isInsurance,
      clearContact: isInsurance,
      clearCustomerMapping: isInsurance,
      patientSnapshot: patientSnapshot,
      membershipId: resolvedMembershipId,
      clearMembershipId: resolvedMembershipId == null,
      clearPrescriptionId: patientChanged,
      clearPrescriptionLabel: patientChanged,
    );
  }

  void setPrivateUseContext({
    required SalesDocumentPatientSnapshot patientSnapshot,
    required QuotePaymentContext paymentContext,
    String? membershipId,
    NativeContact? payerContact,
    Prescription? prescription,

    /// Fallback when the dialog has an initial prescription ID but the full
    /// Prescription object was not re-selected/hydrated.
    String? prescriptionId,
  }) {
    final String? resolvedMembershipId = _resolveMembershipId(
      membershipId: membershipId,
      patientSnapshot: patientSnapshot,
    );
    final bool isInsurance = paymentContext == QuotePaymentContext.insurance;
    final NativeContact? insurancePayer = isInsurance
        ? _requiredInsurancePayerContact(payerContact)
        : null;
    final String? resolvedPrescriptionId =
        _clean(prescription?.prescriptionId) ?? _clean(prescriptionId);
    final String? resolvedPrescriptionLabel = prescription == null
        ? (resolvedPrescriptionId == null ? null : state.prescriptionLabel)
        : _prescriptionLabel(prescription);
    state = state.copyWith(
      purchaseContext: QuotePurchaseContext.privateUse,
      paymentContext: isInsurance
          ? QuotePaymentContext.insurance
          : QuotePaymentContext.directPay,
      payer: insurancePayer,
      clearPayer: !isInsurance,
      clearContact: isInsurance,
      clearCustomerMapping: isInsurance,
      patientSnapshot: patientSnapshot,
      // Membership is only retained for insurance quotes.
      membershipId: isInsurance ? resolvedMembershipId : null,
      clearMembershipId: !isInsurance || resolvedMembershipId == null,
      // Prescription is retained for all private-use quotes.
      // It is required for insurance, optional for direct-pay.
      prescriptionId: resolvedPrescriptionId,
      prescriptionLabel: resolvedPrescriptionLabel,
      clearPrescriptionId: resolvedPrescriptionId == null,
      clearPrescriptionLabel: resolvedPrescriptionId == null,
    );
  }

  void clearPatientContext() {
    state = state.copyWith(
      paymentContext: QuotePaymentContext.directPay,
      clearPatientSnapshot: true,
      clearMembershipId: true,
      clearPrescriptionId: true,
      clearPrescriptionLabel: true,
    );
  }

  void setPrescription(Prescription prescription) {
    final String prescriptionId = prescription.prescriptionId.trim();
    if (prescriptionId.isEmpty) return;
    state = state.copyWith(
      prescriptionId: prescriptionId,
      prescriptionLabel: _prescriptionLabel(prescription),
    );
  }

  void clearPrescription() {
    state = state.copyWith(
      clearPrescriptionId: true,
      clearPrescriptionLabel: true,
    );
  }

  void applyState(QuoteMetaState next) {
    final NativeContact? safeContact = _safeContactForPolicy(next.contact);
    final QuotePaymentContext safePaymentContext =
        next.purchaseContext.isCompany
        ? QuotePaymentContext.directPay
        : next.paymentContext;
    state = QuoteMetaState(
      editingQuoteId: next.editingQuoteId,
      contact: safeContact,
      payer: next.payer ?? safeContact,
      nativeContactId: next.nativeContactId,
      zohoContactId: next.zohoContactId,
      mappedCustomerName: next.mappedCustomerName,
      reference: _clean(next.reference),
      customerNotes: _clean(next.customerNotes),
      purchaseContext: next.purchaseContext,
      paymentContext: safePaymentContext,
      fulfilmentMethod: next.fulfilmentMethod,
      quoteDate: QuoteMetaState.normalizeDate(next.quoteDate),
      expiryDate: QuoteMetaState.normalizeDate(next.expiryDate),
      deliveryAddress: next.fulfilmentMethod.isDelivery
          ? next.deliveryAddress
          : null,
      patientSnapshot: next.purchaseContext.isPrivateUse
          ? next.patientSnapshot
          : null,
      membershipId:
          next.purchaseContext.isPrivateUse && safePaymentContext.isInsurance
          ? _clean(next.resolvedMembershipId)
          : null,
      prescriptionId: next.purchaseContext.isPrivateUse
          ? _clean(next.resolvedPrescriptionId)
          : null,
      prescriptionLabel: next.purchaseContext.isPrivateUse
          ? _clean(next.prescriptionLabel)
          : null,
    );
  }

  void applyZohoMeta({
    required String editingQuoteId,
    NativeContact? contact,
    String? nativeContactId,
    String? zohoContactId,
    String? mappedCustomerName,
    String? reference,
    String? customerNotes,
    QuotePurchaseContext purchaseContext = QuotePurchaseContext.privateUse,
    QuotePaymentContext paymentContext = QuotePaymentContext.directPay,
    QuoteFulfilmentMethod fulfilmentMethod = QuoteFulfilmentMethod.delivery,
    DateTime? quoteDate,
    DateTime? expiryDate,
    SalesDocumentAddress? deliveryAddress,
    SalesDocumentPatientSnapshot? patientSnapshot,
    String? membershipId,
    String? prescriptionId,
    String? prescriptionLabel,
  }) {
    final String? id = _clean(editingQuoteId);
    final NativeContact? safeContact = _safeContactForPolicy(contact);
    final String? resolvedMembershipId = patientSnapshot == null
        ? _clean(membershipId)
        : _resolveMembershipId(
            membershipId: membershipId,
            patientSnapshot: patientSnapshot,
          );
    final QuotePaymentContext safePaymentContext = purchaseContext.isCompany
        ? QuotePaymentContext.directPay
        : paymentContext;
    state = QuoteMetaState(
      editingQuoteId: id,
      contact: safeContact,
      payer: safeContact,
      nativeContactId: _clean(nativeContactId),
      zohoContactId: _clean(zohoContactId),
      mappedCustomerName: _clean(mappedCustomerName),
      reference: _clean(reference),
      customerNotes: _clean(customerNotes),
      purchaseContext: purchaseContext,
      paymentContext: safePaymentContext,
      fulfilmentMethod: fulfilmentMethod,
      quoteDate: QuoteMetaState.normalizeDate(quoteDate),
      expiryDate: QuoteMetaState.normalizeDate(expiryDate),
      deliveryAddress: deliveryAddress,
      patientSnapshot: patientSnapshot,
      membershipId: resolvedMembershipId,
      prescriptionId: _clean(prescriptionId),
      prescriptionLabel: _clean(prescriptionLabel),
    );
  }

  /// Member payer identity is never inferred from an untrusted editor selection.
  NativeContact? _safeContactForPolicy(NativeContact? contact) {
    if (_isMemberScoped) return null;
    return contact;
  }

  NativeContact? _requiredInsurancePayerContact(NativeContact? payer) {
    if (payer == null ||
        (payer.accountNumber).trim().isEmpty ||
        !payer.isInsurancePayer) {
      return null;
    }
    return payer;
  }

  String? _resolveMembershipId({
    required String? membershipId,
    required SalesDocumentPatientSnapshot patientSnapshot,
  }) {
    return _clean(membershipId) ?? _clean(patientSnapshot.membershipId);
  }

  static String _prescriptionLabel(Prescription prescription) {
    final List<String> parts = <String>[
      if (_clean(prescription.fileName) != null) prescription.fileName.trim(),
      if (_clean(prescription.prescribedOn) != null)
        prescription.prescribedOn!.trim(),
      prescription.status.label,
    ];
    final String label = parts
        .map((String value) => value.trim())
        .where((String value) => value.isNotEmpty)
        .join(' · ')
        .trim();
    return label.isEmpty ? prescription.prescriptionId : label;
  }

  static DateTime _normalize(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static DateTime _today() {
    return _normalize(DateTime.now());
  }

  static DateTime _defaultExpiry(DateTime quoteDate) {
    return _normalize(quoteDate.add(const Duration(days: 30)));
  }

  static String? _clean(String? value) {
    final String text = (value ?? '').trim();
    return text.isEmpty ? null : text;
  }
}
