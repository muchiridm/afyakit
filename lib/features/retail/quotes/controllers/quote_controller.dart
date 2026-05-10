// lib/features/retail/quotes/controllers/quote_controller.dart

import 'dart:async';
import 'dart:typed_data';

import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/contacts/zoho_contacts_service.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_engine.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_state.dart';
import 'package:afyakit/features/retail/quotes/controllers/quotes_list_controller.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteControllerProvider =
    StateNotifierProvider<QuoteController, QuoteState>(
      (ref) => QuoteController(ref),
    );

class QuoteController extends StateNotifier<QuoteState> {
  QuoteController(this._ref) : super(const QuoteState()) {
    _engine = QuoteEngine(_ref);

    _ref.listen<String?>(zohoContactsAccountScopeProvider, (prev, next) {
      final p = (prev ?? '').trim();
      final n = (next ?? '').trim();
      if (p == n) return;

      if (_policy != QuoteContactPolicy.memberScoped) return;

      unawaited(_ensureMemberContactBound(showError: false));
    });

    _ref.listen<QuoteContactPolicy>(quoteContactPolicyProvider, (prev, next) {
      if (prev == next) return;

      if (next == QuoteContactPolicy.memberScoped) {
        unawaited(_ensureMemberContactBound(showError: false));
      }
    });
  }

  final Ref _ref;
  late final QuoteEngine _engine;

  bool get _busy => state.busy;

  QuoteLinesController get _linesCtl =>
      _ref.read(quoteLinesControllerProvider.notifier);

  QuoteMetaController get _metaCtl =>
      _ref.read(quoteMetaControllerProvider.notifier);

  QuoteMetaState get _meta => _ref.read(quoteMetaControllerProvider);

  QuoteContactPolicy get _policy => _ref.read(quoteContactPolicyProvider);

  Future<void>? _memberContactBindFuture;
  String? _memberContactBindAcct;

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

  void setDeliveryAddress(SalesDocumentAddress? address) {
    if (_busy) return;
    _metaCtl.setDeliveryAddress(address);
  }

  void clearDeliveryAddress() {
    if (_busy) return;
    _metaCtl.clearDeliveryAddress();
  }

  Future<void> ensureReady({
    String? editingQuoteId,
    required bool requirePrices,
  }) async {
    if (_busy) return;

    final nextId = (editingQuoteId ?? '').trim();
    final prevEditingId = (state.editingQuoteId ?? '').trim();
    final prevLoadedId = (state.loadedEditId ?? '').trim();

    final shouldClearLines = _engine.shouldClearLinesOnSwitch(
      prevEditingId: prevEditingId.isEmpty ? null : prevEditingId,
      prevLoadedId: prevLoadedId.isEmpty ? null : prevLoadedId,
      nextEditingId: nextId,
    );

    if (nextId.isEmpty) {
      _metaCtl.beginNew();
      state = const QuoteState();

      // Member-scoped quote:
      // Do not block the editor while resolving the Zoho customer contact.
      // The UI can show the member's local account immediately while the real
      // Zoho contact is resolved in the background.
      //
      // Submit still calls _ensureMemberContactBound(showError: true), so the
      // actual Zoho contact requirement remains enforced before quote creation.
      if (_policy == QuoteContactPolicy.memberScoped) {
        unawaited(_ensureMemberContactBound(showError: false));
      }

      await ensureDraftFromLines(requirePrices: requirePrices);
      return;
    }

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

  Future<void> _ensureMemberContactBound({bool showError = false}) async {
    final QuoteContactPolicy policy = _ref.read(quoteContactPolicyProvider);
    final bool isMemberScoped = policy == QuoteContactPolicy.memberScoped;
    if (!isMemberScoped) return;

    final String acct = (_ref.read(zohoContactsAccountScopeProvider) ?? '')
        .trim();

    if (acct.isEmpty) {
      if (showError) {
        SnackService.showError('Missing account scope.');
      }
      return;
    }

    final ZohoContact? current = _meta.contact;
    final String currentAcct = (current?.accountNumber ?? '').trim();

    if (current != null && currentAcct == acct) return;

    final Future<void>? inFlight = _memberContactBindFuture;
    if (inFlight != null && _memberContactBindAcct == acct) {
      await inFlight;
      return;
    }

    late final Future<void> bindFuture;
    bindFuture = () async {
      try {
        final ZohoContactsService svc = await _ref.read(
          zohoContactsServiceProvider.future,
        );

        final ZohoContact? best = await svc.getByAccountNumber(
          acct,
          type: ZohoContactTypeFilter.customerOnly,
        );

        if (best == null) {
          if (showError) {
            SnackService.showError('Your customer profile is missing.');
          }
          return;
        }

        final ZohoContact? latest = _meta.contact;
        final String latestAcct = (latest?.accountNumber ?? '').trim();
        if (latest != null && latestAcct == acct) return;

        _metaCtl.setContact(best);
      } catch (_) {
        if (showError) {
          SnackService.showError('Failed to resolve customer profile.');
        }
      } finally {
        if (identical(_memberContactBindFuture, bindFuture)) {
          _memberContactBindFuture = null;
          _memberContactBindAcct = null;
        }
      }
    }();

    _memberContactBindAcct = acct;
    _memberContactBindFuture = bindFuture;

    await bindFuture;
  }

  Future<String?> submit({required bool requirePrices}) async {
    if (_busy) return null;

    if (_policy == QuoteContactPolicy.memberScoped) {
      await _ensureMemberContactBound(showError: true);
      if (_meta.contact == null) {
        SnackService.showError('Could not resolve your customer profile.');
        return null;
      }
    }

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

        _invalidateQuoteCaches(id);

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

      if (createdId.isNotEmpty) {
        _invalidateQuoteCaches(createdId);
      } else {
        _invalidateQuotesList();
      }

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

  void patchDraft({
    dynamic contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
    DateTime? expiryDate,
    SalesDocumentAddress? deliveryAddress,
  }) {
    if (_busy) return;

    try {
      _metaCtl.setContact(contact as dynamic);
    } catch (_) {}

    if (reference != null) _metaCtl.setReference(reference);
    if (customerNotes != null) _metaCtl.setCustomerNotes(customerNotes);
    if (quoteDate != null) _metaCtl.setQuoteDate(quoteDate);
    if (expiryDate != null) _metaCtl.setExpiryDate(expiryDate);
    if (deliveryAddress != null) {
      _metaCtl.setDeliveryAddress(deliveryAddress);
    }
  }

  void _invalidateQuotesList() {
    for (final s in RetailDocScope.values) {
      _ref.invalidate(quotesListControllerProvider(s));
    }
  }

  void _invalidateQuoteCaches(String quoteId) {
    final id = quoteId.trim();
    if (id.isEmpty) return;
    _invalidateQuotesList();
  }

  Future<bool> deleteQuote(String quoteId) async {
    if (_busy) return false;

    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(submitting: true, clearError: true);

    try {
      await _engine.delete(id);

      _invalidateQuoteCaches(id);

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

      _invalidateQuoteCaches(id);

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

      _invalidateQuoteCaches(id);

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

      _invalidateQuoteCaches(id);

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
        deliveryAddress: meta.deliveryAddress,
      );

      state = state.copyWith(loadingEdit: false, loadedEditId: id);

      await ensureDraftFromLines(requirePrices: requirePrices);
    } catch (e) {
      state = state.copyWith(loadingEdit: false, error: e.toString());
      SnackService.showError('Failed to load quote');
    }
  }
}
