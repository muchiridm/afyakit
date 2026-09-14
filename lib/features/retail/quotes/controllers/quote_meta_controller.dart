// lib/features/retail/quotes/controllers/quote_meta_controller.dart

import 'package:afyakit/features/clinical/prescriptions/models/prescription_model.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/providers/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/controllers/states/quote_meta_state.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_context.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteMetaControllerProvider =
    StateNotifierProvider<QuoteMetaController, QuoteMetaState>(
      (Ref ref) => QuoteMetaController(ref),
    );

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
      purchaseContext: wasEditing
          ? QuotePurchaseContext.privateUse
          : state.purchaseContext,
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
      purchaseContext: QuotePurchaseContext.privateUse,
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

  void setPrivateUseContext({
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
      purchaseContext: QuotePurchaseContext.privateUse,
      paymentContext: isInsurance
          ? QuotePaymentContext.insurance
          : QuotePaymentContext.directPay,
      contact: nextContact,
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
    final ZohoContact? safeContact = _safeContactForPolicy(next.contact);

    final QuotePaymentContext safePaymentContext =
        next.purchaseContext.isCompany
        ? QuotePaymentContext.directPay
        : next.paymentContext;

    state = QuoteMetaState(
      editingQuoteId: next.editingQuoteId,
      contact: safeContact,
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
    ZohoContact? contact,
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
    final ZohoContact? safeContact = _safeContactForPolicy(contact);

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
