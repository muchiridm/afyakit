// lib/features/retail/quotes/controllers/quote_controller.dart

import 'package:afyakit/features/retail/contacts/providers/zoho_contact_scope_providers.dart';
import 'package:afyakit/features/retail/contacts/services/zoho_contacts_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/quotes/controllers/quote_engine.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final quoteControllerProvider =
    StateNotifierProvider<QuoteController, QuoteState>(
      (ref) => QuoteController(ref),
    );

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

class QuoteController extends StateNotifier<QuoteState> {
  QuoteController(this._ref) : super(const QuoteState()) {
    _engine = QuoteEngine(_ref);
  }

  final Ref _ref;
  late final QuoteEngine _engine;

  bool get _busy => state.busy;

  QuoteLinesController get _linesCtl =>
      _ref.read(quoteLinesControllerProvider.notifier);

  QuoteMetaController get _metaCtl =>
      _ref.read(quoteMetaControllerProvider.notifier);

  QuoteMetaState get _meta => _ref.read(quoteMetaControllerProvider);

  // ───────────────────────── Public API ─────────────────────────

  void setError(String? message) {
    final msg = (message ?? '').trim();
    state = state.copyWith(error: msg.isEmpty ? null : msg);
  }

  void reset() {
    if (_busy) return;
    state = const QuoteState();
    _linesCtl.clear();
    _metaCtl.clearAll();
  }

  void cancelEdit() {
    if (_busy) return;
    state = const QuoteState();
    _linesCtl.clear();
    _metaCtl.clearAll();
    SnackService.showSuccess('Edits cancelled');
  }

  Future<void> ensureReady({
    String? editingQuoteId,
    required bool requirePrices,
  }) async {
    if (_busy) return;

    // ✅ bind member contact ASAP (prevents “Customer → Name” lag where possible)
    await _ensureMemberContactBound();

    final nextId = (editingQuoteId ?? '').trim();
    final prevEditingId = (state.editingQuoteId ?? '').trim();
    final prevLoadedId = (state.loadedEditId ?? '').trim();

    final shouldClearLines = _engine.shouldClearLinesOnSwitch(
      prevEditingId: prevEditingId.isEmpty ? null : prevEditingId,
      prevLoadedId: prevLoadedId.isEmpty ? null : prevLoadedId,
      nextEditingId: nextId,
    );

    // ───────────────────────── NEW MODE ─────────────────────────
    if (nextId.isEmpty) {
      _metaCtl.beginNew();
      state = const QuoteState();

      // (member contact already attempted above)
      await ensureDraftFromLines(requirePrices: requirePrices);
      return;
    }

    // ───────────────────────── EDIT MODE ─────────────────────────
    final switchingTarget = prevEditingId != nextId || prevLoadedId != nextId;

    if (switchingTarget) {
      _linesCtl.clear();
      _metaCtl.clearAll();
      _metaCtl.beginEdit(nextId);
      state = const QuoteState().copyWith(editingQuoteId: nextId);
    } else {
      if ((state.editingQuoteId ?? '').trim().isEmpty) {
        state = state.copyWith(editingQuoteId: nextId);
      }
      _metaCtl.beginEdit(nextId);
    }

    if (shouldClearLines) _linesCtl.clear();

    await ensureLoadedForEdit(nextId, requirePrices: requirePrices);
  }

  bool get _isMemberMode {
    final acct = (_ref.read(zohoContactsAccountScopeProvider) ?? '').trim();
    return acct.isNotEmpty;
  }

  Future<void> _ensureMemberContactBound({bool showError = false}) async {
    if (!_isMemberMode) return;

    final meta = _meta;
    if (meta.contact != null) return;

    final acct = (_ref.read(zohoContactsAccountScopeProvider) ?? '').trim();

    try {
      final svc = await _ref.read(zohoContactsServiceProvider.future);

      final items = await svc.list(
        accountNumber: acct,
        type: ZohoContactTypeFilter.customerOnly,
        perPage: 5,
        page: 1,
      );

      if (items.isEmpty) {
        if (showError) {
          SnackService.showError('Your customer profile is missing.');
        }
        return;
      }

      _metaCtl.setContact(items.first);
    } catch (_) {
      if (showError) {
        SnackService.showError('Failed to resolve customer profile.');
      }
    }
  }

  Future<String?> submit({required bool requirePrices}) async {
    if (_busy) return null;

    // ✅ Hard rule: member must always resolve contact automatically
    await _ensureMemberContactBound(showError: true);

    final meta = _meta;

    final err = _engine.validateForSubmitV2(
      meta: meta,
      requirePrices: requirePrices,
      isEditing: state.isEditing,
    );
    if (err != null) {
      SnackService.showError(err);
      return null;
    }

    final missing = _engine.missingPriceLineCount();
    if (requirePrices && missing > 0) {
      SnackService.showInfo('$missing item(s) missing price.');
    }

    state = state.copyWith(
      submitting: true,
      clearError: true,
      clearLastCreatedId: true,
    );

    try {
      final payload = _engine.buildPayloadDraftFromMeta(
        meta: meta,
        requirePrices: requirePrices,
      );

      if (state.isEditing) {
        final id = (state.editingQuoteId ?? '').trim();
        if (id.isEmpty) {
          state = state.copyWith(submitting: false);
          SnackService.showError('Missing quote id');
          return null;
        }

        await _engine.update(
          id,
          payload,
          quoteDate: meta.quoteDate,
          expiryDate: meta.expiryDate,
        );

        state = state.copyWith(submitting: false);
        SnackService.showSuccess('Quote updated');
        return id;
      }

      final created = await _engine.create(
        payload,
        quoteDate: meta.quoteDate,
        expiryDate: meta.expiryDate,
      );

      final createdId = created.quoteId.trim();

      _linesCtl.clear();
      _metaCtl.clearAll();

      state = state.copyWith(
        submitting: false,
        lastCreatedQuoteId: createdId.isEmpty ? null : createdId,
      );

      SnackService.showSuccess('Quote created');
      return createdId.isEmpty ? null : createdId;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      SnackService.showError(
        state.isEditing ? 'Failed to update quote' : 'Failed to create quote',
      );
      return null;
    }
  }

  // Legacy compatibility
  void patchDraft({
    dynamic contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) {
    if (_busy) return;

    try {
      _metaCtl.setContact(contact as dynamic);
    } catch (_) {}

    if (reference != null) _metaCtl.setReference(reference);
    if (customerNotes != null) _metaCtl.setCustomerNotes(customerNotes);
    if (quoteDate != null) _metaCtl.setQuoteDate(quoteDate);
    if (expiryDate != null) _metaCtl.setExpiryDate(expiryDate);
  }

  Future<bool> deleteQuote(String quoteId) async {
    if (_busy) return false;

    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(submitting: true, clearError: true);

    try {
      await _engine.delete(id);

      if ((state.editingQuoteId ?? '').trim() == id) {
        _linesCtl.clear();
        _metaCtl.clearAll();
        state = const QuoteState();
      } else {
        state = state.copyWith(submitting: false);
      }

      SnackService.showSuccess('Quote deleted');
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      SnackService.showError('Failed to delete quote');
      return false;
    }
  }

  Future<Uint8List?> getPdfBytes(String quoteId) async {
    if (_busy) return null;

    final id = quoteId.trim();
    if (id.isEmpty) return null;

    state = state.copyWith(downloadingPdf: true, clearError: true);

    try {
      final bytes = await _engine.getPdf(id);
      state = state.copyWith(downloadingPdf: false);
      return bytes;
    } catch (e) {
      state = state.copyWith(downloadingPdf: false, error: e.toString());
      SnackService.showError('Failed to load PDF');
      return null;
    }
  }

  Future<bool> emailQuote(String quoteId) async {
    if (_busy) return false;
    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);
    try {
      await _engine.email(id);
      state = state.copyWith(sending: false);
      SnackService.showSuccess('Quote sent');
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
      SnackService.showError('Failed to send quote');
      return false;
    }
  }

  Future<bool> markQuoteSent(String quoteId) async {
    if (_busy) return false;
    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);
    try {
      await _engine.markSent(id);
      state = state.copyWith(sending: false);
      SnackService.showSuccess('Marked as sent');
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
      SnackService.showError('Failed to mark as sent');
      return false;
    }
  }

  Future<Map<String, dynamic>?> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) async {
    if (_busy) return null;
    final id = quoteId.trim();
    if (id.isEmpty) return null;

    state = state.copyWith(converting: true, clearError: true);
    try {
      final res = await _engine.convertToInvoice(
        id,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
      );
      state = state.copyWith(converting: false);
      SnackService.showSuccess('Converted to invoice');
      return res;
    } catch (e) {
      state = state.copyWith(converting: false, error: e.toString());
      SnackService.showError('Failed to convert to invoice');
      return null;
    }
  }

  Future<void> ensureDraftFromLines({required bool requirePrices}) async {
    if (_busy) return;
    if (!requirePrices) return;

    final missing = _engine.missingPriceLineCount();
    if (missing > 0) {
      SnackService.showInfo(
        '$missing item(s) missing price — you can enter prices manually.',
      );
    }
  }

  Future<void> ensureLoadedForEdit(
    String quoteId, {
    required bool requirePrices,
  }) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;
    if (_busy) return;
    if ((state.loadedEditId ?? '').trim() == id) return;

    state = state.copyWith(
      loadingEdit: true,
      clearError: true,
      editingQuoteId: id,
    );

    try {
      final q = await _engine.loadQuote(id);

      _engine.setLinesFromZoho(q);

      final meta = _engine.metaFromZoho(q);
      _metaCtl.applyZohoMeta(
        editingQuoteId: id,
        contact: meta.contact,
        reference: meta.reference,
        customerNotes: meta.customerNotes,
        quoteDate: meta.quoteDate,
        expiryDate: meta.expiryDate,
      );

      state = state.copyWith(loadingEdit: false, loadedEditId: id);

      await ensureDraftFromLines(requirePrices: requirePrices);
    } catch (e) {
      state = state.copyWith(loadingEdit: false, error: e.toString());
      SnackService.showError('Failed to load quote');
    }
  }
}
