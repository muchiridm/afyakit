import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';

@immutable
class QuoteMetaState {
  const QuoteMetaState({
    this.editingQuoteId,
    this.contact,
    this.reference,
    this.customerNotes,
    this.quoteDate,
  });

  final String? editingQuoteId;
  final ZohoContact? contact;
  final String? reference;
  final String? customerNotes;
  final DateTime? quoteDate;

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
    );
  }

  static DateTime? normalizeDate(DateTime? d) {
    if (d == null) return null;
    return DateTime(d.year, d.month, d.day);
  }
}

class QuoteMetaController extends StateNotifier<QuoteMetaState> {
  QuoteMetaController() : super(const QuoteMetaState());

  static DateTime _normalize(DateTime d) => DateTime(d.year, d.month, d.day);

  /// Enter "new quote" mode. Do NOT clear customer/meta.
  void beginNew() {
    if ((state.editingQuoteId ?? '').trim().isEmpty) return;
    state = state.copyWith(clearEditingQuoteId: true);
  }

  /// Enter "edit quote" mode (sets editingQuoteId).
  void beginEdit(String quoteId) {
    final id = quoteId.trim();
    state = state.copyWith(editingQuoteId: id.isEmpty ? null : id);
  }

  void clearAll() => state = const QuoteMetaState();

  void setContact(ZohoContact c) {
    // accept "title-only" contacts too (some UIs show title even before id)
    final id = c.contactId.trim();
    final title = c.title.trim();
    if (id.isEmpty && title.isEmpty) return;
    state = state.copyWith(contact: c);
  }

  void clearContact() => state = state.copyWith(clearContact: true);

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

  void applyZohoMeta({
    required String editingQuoteId,
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
  }) {
    final id = editingQuoteId.trim();
    state = QuoteMetaState(
      editingQuoteId: id.isEmpty ? null : id,
      contact: contact,
      reference: (reference ?? '').trim().isEmpty ? null : reference!.trim(),
      customerNotes: (customerNotes ?? '').trim().isEmpty
          ? null
          : customerNotes!.trim(),
      quoteDate: QuoteMetaState.normalizeDate(quoteDate),
    );
  }
}

/// IMPORTANT: do NOT autoDispose.
/// This keeps customer selection alive across Catalog ↔ QuoteEditor navigation.
final quoteMetaControllerProvider =
    StateNotifierProvider<QuoteMetaController, QuoteMetaState>(
      (ref) => QuoteMetaController(),
    );
