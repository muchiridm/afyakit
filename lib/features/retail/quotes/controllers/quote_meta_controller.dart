// lib/features/retail/quotes/controllers/quote_meta_controller.dart

import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_sale_context.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class QuoteMetaState {
  const QuoteMetaState({
    this.editingQuoteId,
    this.contact,
    this.reference,
    this.customerNotes,
    this.saleContext = QuoteSaleContext.clinical,
    this.paymentContext = QuotePaymentContext.directPay,
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

  /// clinical:
  ///   Patient-linked sale. Requires patient + delivery address.
  ///
  /// general:
  ///   OTC / B2B / walk-in / institutional sale. Patient and delivery optional.
  final QuoteSaleContext saleContext;

  /// directPay:
  ///   The selected Zoho customer/contact pays directly.
  ///   This includes patient self-pay, parent/guardian paying,
  ///   employer/company direct-pay, OTC, and B2B.
  ///
  /// insurance:
  ///   Insurance payer is billed. Requires clinical sale + membership.
  final QuotePaymentContext paymentContext;

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

  bool get isClinical => saleContext == QuoteSaleContext.clinical;

  bool get isGeneral => saleContext == QuoteSaleContext.general;

  bool get isDirectPay =>
      effectivePaymentContext == QuotePaymentContext.directPay;

  bool get isInsurancePayment {
    return effectivePaymentContext == QuotePaymentContext.insurance;
  }

  /// General sales cannot be insurance claims in the current model.
  QuotePaymentContext get effectivePaymentContext {
    return isGeneral ? QuotePaymentContext.directPay : paymentContext;
  }

  bool get requiresPatient => saleContext.requiresPatient;

  bool get requiresDeliveryAddress => saleContext.requiresDeliveryAddress;

  bool get requiresMembership {
    return isClinical && effectivePaymentContext.requiresMembership;
  }

  bool get requiresPrescription {
    return isClinical && isInsurancePayment;
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
    return isClinical &&
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
    if (isGeneral) return 'Direct-pay general sale';

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
    QuoteSaleContext? saleContext,
    QuotePaymentContext? paymentContext,
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
    final QuoteSaleContext nextSaleContext = saleContext ?? this.saleContext;

    final QuotePaymentContext nextPaymentContext =
        nextSaleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : (paymentContext ?? this.paymentContext);

    return QuoteMetaState(
      editingQuoteId: clearEditingQuoteId
          ? null
          : (editingQuoteId ?? this.editingQuoteId),
      contact: clearContact ? null : (contact ?? this.contact),
      reference: clearReference ? null : (reference ?? this.reference),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
      saleContext: nextSaleContext,
      paymentContext: nextPaymentContext,
      quoteDate: clearQuoteDate ? null : (quoteDate ?? this.quoteDate),
      expiryDate: clearExpiryDate ? null : (expiryDate ?? this.expiryDate),
      deliveryAddress: clearDeliveryAddress
          ? null
          : (deliveryAddress ?? this.deliveryAddress),
      patientSnapshot: clearPatientSnapshot
          ? null
          : (patientSnapshot ?? this.patientSnapshot),
      membershipId: clearMembershipId
          ? null
          : (membershipId ?? this.membershipId),
      prescriptionId: clearPrescriptionId
          ? null
          : (prescriptionId ?? this.prescriptionId),
      prescriptionLabel: clearPrescriptionLabel
          ? null
          : (prescriptionLabel ?? this.prescriptionLabel),
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

  String get _accountNumber {
    return (_ref.read(zohoMemberCustomerScopeProvider)?.accountNumber ?? '')
        .trim();
  }

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
      saleContext: wasEditing ? QuoteSaleContext.clinical : state.saleContext,
      paymentContext: wasEditing
          ? QuotePaymentContext.directPay
          : state.effectivePaymentContext,
      clearContact: wasEditing,
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

  void setSaleContext(QuoteSaleContext saleContext) {
    if (state.saleContext == saleContext) return;

    state = state.copyWith(
      saleContext: saleContext,
      paymentContext: saleContext == QuoteSaleContext.general
          ? QuotePaymentContext.directPay
          : state.effectivePaymentContext,
      clearPrescriptionId: saleContext == QuoteSaleContext.general,
      clearPrescriptionLabel: saleContext == QuoteSaleContext.general,
    );
  }

  void setPaymentContext(QuotePaymentContext paymentContext) {
    if (state.isGeneral) return;

    if (state.paymentContext == paymentContext) return;

    state = state.copyWith(
      saleContext: QuoteSaleContext.clinical,
      paymentContext: paymentContext,
    );
  }

  void setContact(ZohoContact? contact) {
    final ZohoContact? safeContact = _safeContactForPolicy(contact);

    if (_isMemberScoped && safeContact == null) return;

    state = state.copyWith(
      contact: safeContact,
      clearContact: safeContact == null,
    );
  }

  void clearContact() {
    if (_isMemberScoped) return;
    state = state.copyWith(clearContact: true);
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
    ZohoContact? payerContact,
    QuotePaymentContext paymentContext = QuotePaymentContext.directPay,
  }) {
    final String? resolvedMembershipId = _resolveMembershipId(
      membershipId: membershipId,
      patientSnapshot: patientSnapshot,
    );

    final bool isInsurance = paymentContext == QuotePaymentContext.insurance;

    final ZohoContact? nextContact = isInsurance
        ? _requiredInsurancePayerContact(payerContact)
        : state.contact;

    final String? previousPatientId = state.resolvedPatientId;
    final String? nextPatientId = _clean(patientSnapshot.patientId);

    final bool patientChanged =
        previousPatientId != null &&
        nextPatientId != null &&
        previousPatientId != nextPatientId;

    state = state.copyWith(
      saleContext: QuoteSaleContext.clinical,
      paymentContext: isInsurance
          ? QuotePaymentContext.insurance
          : QuotePaymentContext.directPay,
      contact: nextContact,
      patientSnapshot: patientSnapshot,
      membershipId: resolvedMembershipId,
      clearMembershipId: resolvedMembershipId == null,
      clearPrescriptionId: patientChanged,
      clearPrescriptionLabel: patientChanged,
    );
  }

  void setClinicalContext({
    required SalesDocumentPatientSnapshot patientSnapshot,
    required QuotePaymentContext paymentContext,
    String? membershipId,
    ZohoContact? payerContact,
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

    final ZohoContact? nextContact = isInsurance
        ? _requiredInsurancePayerContact(payerContact)
        : state.contact;

    final String? resolvedPrescriptionId =
        _clean(prescription?.prescriptionId) ?? _clean(prescriptionId);

    final String? resolvedPrescriptionLabel = prescription == null
        ? (resolvedPrescriptionId == null ? null : state.prescriptionLabel)
        : _prescriptionLabel(prescription);

    state = state.copyWith(
      saleContext: QuoteSaleContext.clinical,
      paymentContext: isInsurance
          ? QuotePaymentContext.insurance
          : QuotePaymentContext.directPay,
      contact: nextContact,
      patientSnapshot: patientSnapshot,

      // Membership is only retained for insurance quotes.
      membershipId: isInsurance ? resolvedMembershipId : null,
      clearMembershipId: !isInsurance || resolvedMembershipId == null,

      // Prescription is retained for all clinical quotes.
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

  void applyZohoMeta({
    required String editingQuoteId,
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    QuoteSaleContext saleContext = QuoteSaleContext.clinical,
    QuotePaymentContext paymentContext = QuotePaymentContext.directPay,
    DateTime? quoteDate,
    DateTime? expiryDate,
    SalesDocumentAddress? deliveryAddress,
    SalesDocumentPatientSnapshot? patientSnapshot,
    String? membershipId,
    String? prescriptionId,
    String? prescriptionLabel,
  }) {
    final String? id = _clean(editingQuoteId);
    final ZohoContact? safeContact = _safeContactForPolicy(contact);

    final String? resolvedMembershipId = patientSnapshot == null
        ? _clean(membershipId)
        : _resolveMembershipId(
            membershipId: membershipId,
            patientSnapshot: patientSnapshot,
          );

    final QuotePaymentContext safePaymentContext =
        saleContext == QuoteSaleContext.general
        ? QuotePaymentContext.directPay
        : paymentContext;

    state = QuoteMetaState(
      editingQuoteId: id,
      contact: safeContact,
      reference: _clean(reference),
      customerNotes: _clean(customerNotes),
      saleContext: saleContext,
      paymentContext: safePaymentContext,
      quoteDate: QuoteMetaState.normalizeDate(quoteDate),
      expiryDate: QuoteMetaState.normalizeDate(expiryDate),
      deliveryAddress: deliveryAddress,
      patientSnapshot: patientSnapshot,
      membershipId: resolvedMembershipId,
      prescriptionId: _clean(prescriptionId),
      prescriptionLabel: _clean(prescriptionLabel),
    );
  }

  ZohoContact? _safeContactForPolicy(ZohoContact? contact) {
    if (contact == null) return null;
    if (!_isMemberScoped) return contact;

    final String expected = _accountNumber;
    final String actual = (contact.accountNumber ?? '').trim();

    if (expected.isEmpty || actual.isEmpty) return contact;

    return actual == expected ? contact : null;
  }

  ZohoContact? _requiredInsurancePayerContact(ZohoContact? payerContact) {
    final String payerContactId = (payerContact?.contactId ?? '').trim();

    if (payerContactId.isEmpty) {
      return null;
    }

    // Insurance is special:
    // the selected payer/insurer MUST become the billed Zoho customer.
    //
    // Do not apply member-scoped account-number filtering here, because the
    // insurer's account number is expected to differ from the patient's/member's
    // account number.
    return payerContact;
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

final quoteMetaControllerProvider =
    StateNotifierProvider<QuoteMetaController, QuoteMetaState>(
      (Ref ref) => QuoteMetaController(ref),
    );
