import 'package:afyakit/features/retail/sales/invoices/models/invoice_draft.dart';
import 'package:flutter/foundation.dart';

@immutable
class InvoiceState {
  const InvoiceState({
    this.submitting = false,
    this.loadingEdit = false,
    this.error,
    this.lastCreatedInvoiceId,
    this.editingInvoiceId,
    this.loadedEditId,
    InvoiceDraft? draft,
    this.invoiceDate,
  }) : draft = draft ?? const InvoiceDraft();

  final bool submitting;
  final bool loadingEdit;

  final String? error;
  final String? lastCreatedInvoiceId;

  final String? editingInvoiceId;
  final String? loadedEditId;

  final InvoiceDraft draft;
  final DateTime? invoiceDate;

  bool get isEditing => (editingInvoiceId ?? '').trim().isNotEmpty;
  bool get busy => submitting || loadingEdit;

  bool get hasLines => draft.lines.isNotEmpty;
  num get total => draft.total;
  String get customerLabel => draft.displayContactName;

  InvoiceState copyWith({
    bool? submitting,
    bool? loadingEdit,
    String? error,
    bool clearError = false,
    String? lastCreatedInvoiceId,
    bool clearLastCreatedId = false,
    String? editingInvoiceId,
    bool clearEditingInvoiceId = false,
    String? loadedEditId,
    bool clearLoadedEditId = false,
    InvoiceDraft? draft,
    bool clearDraft = false,
    DateTime? invoiceDate,
    bool clearInvoiceDate = false,
  }) {
    return InvoiceState(
      submitting: submitting ?? this.submitting,
      loadingEdit: loadingEdit ?? this.loadingEdit,
      error: clearError ? null : (error ?? this.error),
      lastCreatedInvoiceId: clearLastCreatedId
          ? null
          : (lastCreatedInvoiceId ?? this.lastCreatedInvoiceId),
      editingInvoiceId: clearEditingInvoiceId
          ? null
          : (editingInvoiceId ?? this.editingInvoiceId),
      loadedEditId: clearLoadedEditId
          ? null
          : (loadedEditId ?? this.loadedEditId),
      draft: clearDraft ? const InvoiceDraft() : (draft ?? this.draft),
      invoiceDate: clearInvoiceDate ? null : (invoiceDate ?? this.invoiceDate),
    );
  }
}
