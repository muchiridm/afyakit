// lib/features/retail/quotes/controllers/quote_state.dart

import 'package:flutter/material.dart';

@immutable
class QuoteState {
  const QuoteState({
    this.submitting = false,
    this.loadingEdit = false,
    this.downloadingPdf = false,
    this.sending = false,
    this.converting = false,
    this.error,
    this.lastCreatedQuoteId,
    this.editingQuoteId,
    this.loadedEditId,
  });

  final bool submitting;
  final bool loadingEdit;

  final bool downloadingPdf;
  final bool sending;
  final bool converting;

  final String? error;
  final String? lastCreatedQuoteId;

  final String? editingQuoteId;
  final String? loadedEditId;

  bool get isEditing => (editingQuoteId ?? '').trim().isNotEmpty;

  bool get busy =>
      submitting || loadingEdit || downloadingPdf || sending || converting;

  QuoteState copyWith({
    bool? submitting,
    bool? loadingEdit,
    bool? downloadingPdf,
    bool? sending,
    bool? converting,
    String? error,
    bool clearError = false,
    String? lastCreatedQuoteId,
    bool clearLastCreatedId = false,
    String? editingQuoteId,
    bool clearEditingQuoteId = false,
    String? loadedEditId,
    bool clearLoadedEditId = false,
  }) {
    return QuoteState(
      submitting: submitting ?? this.submitting,
      loadingEdit: loadingEdit ?? this.loadingEdit,
      downloadingPdf: downloadingPdf ?? this.downloadingPdf,
      sending: sending ?? this.sending,
      converting: converting ?? this.converting,
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
    );
  }
}
