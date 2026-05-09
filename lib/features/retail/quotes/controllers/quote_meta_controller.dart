// lib/features/retail/quotes/controllers/quote_meta_controller.dart

import 'package:afyakit/features/retail/contacts/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/contacts/zoho_contact.dart';

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
  });

  final String? editingQuoteId;
  final ZohoContact? contact;
  final String? reference;
  final String? customerNotes;

  /// Zoho: `date` (estimate_date)
  final DateTime? quoteDate;

  /// Zoho: `expiry_date`
  final DateTime? expiryDate;

  final SalesDocumentAddress? deliveryAddress;

  bool get isEditing => (editingQuoteId ?? '').trim().isNotEmpty;

  String get customerIdResolved => (contact?.contactId ?? '').trim();

  String get displayContactName {
    final t = (contact?.title ?? '').trim();
    return t.isNotEmpty ? t : 'Customer';
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
      (_ref.read(zohoContactsAccountScopeProvider) ?? '').trim();

  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;

  /// Enter "new quote" mode.
  /// - Picker: keep customer selection (persist across Catalog ↔ QuoteEditor)
  /// - MemberScoped: clear stale contact so UI never shows previous user's name
  void beginNew() {
    final wasEditing = (state.editingQuoteId ?? '').trim().isNotEmpty;

    if (_isMemberScoped) {
      state = state.copyWith(clearEditingQuoteId: true);
      return;
    }

    // Picker mode: only clear editingQuoteId; keep customer/meta draft state.
    if (wasEditing) {
      state = state.copyWith(clearEditingQuoteId: true);
    }
  }

  /// Enter "edit quote" mode (sets editingQuoteId).
  void beginEdit(String quoteId) {
    final id = quoteId.trim();
    state = state.copyWith(editingQuoteId: id.isEmpty ? null : id);
  }

  void clearAll() => state = const QuoteMetaState();

  void setContact(ZohoContact? c) {
    if (_isMemberScoped) {
      // Member scoped: reject clearing.
      if (c == null) return;

      // Enforce scope if accountNumber present on payload.
      final nextAcct = (c.accountNumber ?? '').trim();
      final acct = _acct;

      if (acct.isNotEmpty && nextAcct.isNotEmpty && nextAcct != acct) {
        return;
      }
    }

    state = state.copyWith(contact: c);
  }

  void clearContact() {
    // Member scoped: never allow clearing.
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

  void applyZohoMeta({
    required String editingQuoteId,
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
    DateTime? expiryDate,
    SalesDocumentAddress? deliveryAddress,
  }) {
    final id = editingQuoteId.trim();

    ZohoContact? safeContact = contact;

    // Member scoped: do not accept a contact that doesn't match scope.
    if (_isMemberScoped) {
      final acct = _acct;
      final contactAcct = (contact?.accountNumber ?? '').trim();

      // If account numbers exist, must match; else drop contact to force rebind.
      if (acct.isNotEmpty && contactAcct.isNotEmpty && contactAcct != acct) {
        safeContact = null;
      }
    }

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
    );
  }
}

/// IMPORTANT: do NOT autoDispose.
/// This keeps customer selection alive across Catalog ↔ QuoteEditor navigation.
final quoteMetaControllerProvider =
    StateNotifierProvider<QuoteMetaController, QuoteMetaState>(
      (ref) => QuoteMetaController(ref),
    );
