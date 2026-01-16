// lib/features/retail/sales/quotes/controllers/quote_state.dart

import 'package:afyakit/features/retail/sales/quotes/models/quote_draft.dart';
import 'package:flutter/foundation.dart';

@immutable
class QuoteState {
  const QuoteState({
    this.submitting = false,
    this.loadingEdit = false,
    this.error,
    this.lastCreatedQuoteId,
    this.editingQuoteId,
    this.loadedEditId,
    QuoteDraft? draft,
    this.quoteDate,
  }) : draft = draft ?? const QuoteDraft();

  final bool submitting;
  final bool loadingEdit;

  final String? error;
  final String? lastCreatedQuoteId;

  final String? editingQuoteId;
  final String? loadedEditId;

  final QuoteDraft draft;
  final DateTime? quoteDate;

  bool get isEditing => (editingQuoteId ?? '').trim().isNotEmpty;
  bool get busy => submitting || loadingEdit;

  bool get hasLines => draft.lines.isNotEmpty;
  num get total => draft.total;
  String get customerLabel => draft.displayContactName;

  QuoteState copyWith({
    bool? submitting,
    bool? loadingEdit,
    String? error,
    bool clearError = false,
    String? lastCreatedQuoteId,
    bool clearLastCreatedId = false,
    String? editingQuoteId,
    bool clearEditingQuoteId = false,
    String? loadedEditId,
    bool clearLoadedEditId = false,
    QuoteDraft? draft,
    bool clearDraft = false,
    DateTime? quoteDate,
    bool clearQuoteDate = false,
  }) {
    return QuoteState(
      submitting: submitting ?? this.submitting,
      loadingEdit: loadingEdit ?? this.loadingEdit,
      error: clearError ? null : (error ?? this.error),
      lastCreatedQuoteId: clearLastCreatedId
          ? null
          : (lastCreatedQuoteId ?? this.lastCreatedQuoteId),
      editingQuoteId: clearEditingQuoteId
          ? null
          : (editingQuoteId ?? this.editingQuoteId),
      loadedEditId: clearLoadedEditId
          ? null
          : (loadedEditId ?? this.loadedEditId),
      draft: clearDraft ? const QuoteDraft() : (draft ?? this.draft),
      quoteDate: clearQuoteDate ? null : (quoteDate ?? this.quoteDate),
    );
  }
}
