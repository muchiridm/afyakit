// lib/features/retail/quotes/controllers/quote_meta_controller.dart

import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
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
    this.quoteDate,
    this.expiryDate,
    this.deliveryAddress,
    this.patientSnapshot,
    this.membershipId,
  });

  final String? editingQuoteId;
  final ZohoContact? contact;
  final String? reference;
  final String? customerNotes;

  /// Zoho: `date` / `estimate_date`
  final DateTime? quoteDate;

  /// Zoho: `expiry_date`
  final DateTime? expiryDate;

  final SalesDocumentAddress? deliveryAddress;

  /// Person receiving care/medicine.
  final SalesDocumentPatientSnapshot? patientSnapshot;

  /// Insurance membership used later for:
  /// quote → invoice → claim.
  final String? membershipId;

  bool get isEditing => (editingQuoteId ?? '').trim().isNotEmpty;

  String get customerIdResolved => (contact?.contactId ?? '').trim();

  String get displayContactName {
    final t = (contact?.title ?? '').trim();
    return t.isNotEmpty ? t : 'Customer';
  }

  String? get resolvedPatientId {
    final id = (patientSnapshot?.patientId ?? '').trim();
    return id.isEmpty ? null : id;
  }

  String? get resolvedMembershipId {
    final direct = (membershipId ?? '').trim();
    if (direct.isNotEmpty) return direct;

    final snap = (patientSnapshot?.membershipId ?? '').trim();
    return snap.isEmpty ? null : snap;
  }

  bool get hasPatientContext => resolvedPatientId != null;
  bool get hasInsuranceContext => resolvedMembershipId != null;

  String get patientLabel {
    final name = (patientSnapshot?.fullName ?? '').trim();
    if (name.isNotEmpty) return name;

    final id = (patientSnapshot?.patientId ?? '').trim();
    return id.isNotEmpty ? id : 'Patient';
  }

  String? get patientSubtitle {
    final p = patientSnapshot;
    if (p == null) return null;

    final parts = <String>[
      if ((p.patientNo ?? '').trim().isNotEmpty) p.patientNo!.trim(),
      if ((p.dob ?? '').trim().isNotEmpty) 'DOB ${p.dob!.trim()}',
      if ((p.gender ?? '').trim().isNotEmpty) p.gender!.trim(),
      if ((p.relationship ?? '').trim().isNotEmpty) p.relationship!.trim(),
    ];

    final text = parts.join(' · ').trim();
    return text.isEmpty ? null : text;
  }

  String? get insuranceSubtitle {
    final p = patientSnapshot;
    if (p == null) return null;

    final parts = <String>[
      if ((p.payerName ?? '').trim().isNotEmpty) p.payerName!.trim(),
      if ((p.memberNo ?? '').trim().isNotEmpty) 'Member ${p.memberNo!.trim()}',
      if ((p.scheme ?? '').trim().isNotEmpty) p.scheme!.trim(),
    ];

    final text = parts.join(' · ').trim();
    return text.isEmpty ? null : text;
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
  }) {
    return QuoteMetaState(
      editingQuoteId: clearEditingQuoteId
          ? null
          : (editingQuoteId ?? this.editingQuoteId),
      contact: clearContact ? null : (contact ?? this.contact),
      reference: clearReference ? null : (reference ?? this.reference),
      customerNotes: clearCustomerNotes
          ? null
          : (customerNotes ?? this.customerNotes),
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
    );
  }

  static DateTime? normalizeDate(DateTime? d) {
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }
}

class QuoteMetaController extends StateNotifier<QuoteMetaState> {
  QuoteMetaController(this._ref) : super(const QuoteMetaState());

  final Ref _ref;

  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  QuoteContactPolicy get _policy => _ref.read(quoteContactPolicyProvider);

  String get _acct =>
      (_ref.read(zohoMemberCustomerScopeProvider)?.accountNumber ?? '').trim();

  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;

  void beginNew() {
    final wasEditing = (state.editingQuoteId ?? '').trim().isNotEmpty;

    if (_isMemberScoped) {
      state = state.copyWith(clearEditingQuoteId: true);
      return;
    }

    if (wasEditing) {
      state = state.copyWith(clearEditingQuoteId: true);
    }
  }

  void beginEdit(String quoteId) {
    final id = quoteId.trim();
    state = state.copyWith(editingQuoteId: id.isEmpty ? null : id);
  }

  void clearAll() => state = const QuoteMetaState();

  void setContact(ZohoContact? c) {
    if (_isMemberScoped) {
      if (c == null) return;

      final nextAcct = (c.accountNumber ?? '').trim();
      final acct = _acct;

      if (acct.isNotEmpty && nextAcct.isNotEmpty && nextAcct != acct) {
        return;
      }
    }

    state = state.copyWith(contact: c);
  }

  void clearContact() {
    if (_isMemberScoped) return;
    state = state.copyWith(clearContact: true);
  }

  void setReference(String v) {
    final t = v.trim();
    state = state.copyWith(reference: t.isEmpty ? null : t);
  }

  void setCustomerNotes(String v) {
    final t = v.trim();
    state = state.copyWith(customerNotes: t.isEmpty ? null : t);
  }

  void setQuoteDate(DateTime d) {
    state = state.copyWith(quoteDate: _normalize(d));
  }

  void clearQuoteDate() {
    state = state.copyWith(clearQuoteDate: true);
  }

  void setExpiryDate(DateTime d) {
    state = state.copyWith(expiryDate: _normalize(d));
  }

  void clearExpiryDate() {
    state = state.copyWith(clearExpiryDate: true);
  }

  void setDeliveryAddress(SalesDocumentAddress? a) {
    state = state.copyWith(deliveryAddress: a);
  }

  void clearDeliveryAddress() {
    state = state.copyWith(clearDeliveryAddress: true);
  }

  void setPatientContext({
    required SalesDocumentPatientSnapshot patientSnapshot,
    String? membershipId,
    ZohoContact? payerContact,
  }) {
    final cleanMembershipId = (membershipId ?? '').trim();
    final snapMembershipId = (patientSnapshot.membershipId ?? '').trim();

    final resolvedMembershipId = cleanMembershipId.isNotEmpty
        ? cleanMembershipId
        : (snapMembershipId.isNotEmpty ? snapMembershipId : null);

    final payerContactId = (payerContact?.contactId ?? '').trim();

    state = state.copyWith(
      // Insurance membership selected:
      // bill quote/invoice to the payer contact.
      //
      // Normal patient selected:
      // payerContact is null, so existing customer remains unchanged.
      contact: payerContactId.isNotEmpty ? payerContact : null,
      patientSnapshot: patientSnapshot,
      membershipId: resolvedMembershipId,
    );
  }

  void clearPatientContext() {
    state = state.copyWith(clearPatientSnapshot: true, clearMembershipId: true);
  }

  void applyZohoMeta({
    required String editingQuoteId,
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
    DateTime? expiryDate,
    SalesDocumentAddress? deliveryAddress,
    SalesDocumentPatientSnapshot? patientSnapshot,
    String? membershipId,
  }) {
    final id = editingQuoteId.trim();

    ZohoContact? safeContact = contact;

    if (_isMemberScoped) {
      final acct = _acct;
      final contactAcct = (contact?.accountNumber ?? '').trim();

      if (acct.isNotEmpty && contactAcct.isNotEmpty && contactAcct != acct) {
        safeContact = null;
      }
    }

    final cleanMembershipId = (membershipId ?? '').trim();
    final snapMembershipId = (patientSnapshot?.membershipId ?? '').trim();

    state = QuoteMetaState(
      editingQuoteId: id.isEmpty ? null : id,
      contact: safeContact,
      reference: (reference ?? '').trim().isEmpty ? null : reference!.trim(),
      customerNotes: (customerNotes ?? '').trim().isNotEmpty
          ? customerNotes!.trim()
          : null,
      quoteDate: QuoteMetaState.normalizeDate(quoteDate),
      expiryDate: QuoteMetaState.normalizeDate(expiryDate),
      deliveryAddress: deliveryAddress,
      patientSnapshot: patientSnapshot,
      membershipId: cleanMembershipId.isNotEmpty
          ? cleanMembershipId
          : (snapMembershipId.isNotEmpty ? snapMembershipId : null),
    );
  }
}

/// IMPORTANT: do NOT autoDispose.
/// This keeps customer/patient selection alive across Catalog ↔ QuoteEditor navigation.
final quoteMetaControllerProvider =
    StateNotifierProvider<QuoteMetaController, QuoteMetaState>(
      (ref) => QuoteMetaController(ref),
    );
