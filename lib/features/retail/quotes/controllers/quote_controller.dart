// lib/features/retail/quotes/controllers/quote_controller.dart

import 'dart:async';

import 'package:afyakit/features/retail/contacts/zoho_contact.dart';
import 'package:afyakit/features/retail/contacts/zoho_contacts_providers.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_engine.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_lines_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_member_binding_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_meta_controller.dart';
import 'package:afyakit/features/retail/quotes/controllers/quote_state.dart';
import 'package:afyakit/features/retail/quotes/controllers/quotes_list_controller.dart';
import 'package:afyakit/features/retail/quotes/extensions/quote_contact_policy_enum.dart';
import 'package:afyakit/features/retail/quotes/models/quote_draft.dart';
import 'package:afyakit/features/retail/quotes/providers/quote_contact_policy_provider.dart';
import 'package:afyakit/features/retail/quotes/providers/zoho_quote_provider.dart';
import 'package:afyakit/features/retail/quotes/services/zoho_quotes_service.dart';
import 'package:afyakit/features/retail/shared/extensions/retail_doc_scope_x.dart';
import 'package:afyakit/features/retail/shared/models/sales_document_address.dart';
import 'package:afyakit/features/retail/shared/sales_doc/patient_snapshot.dart';
import 'package:afyakit/shared/services/snack_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final quoteControllerProvider =
    StateNotifierProvider<QuoteController, QuoteState>(
      (Ref ref) => QuoteController(ref),
    );

class QuoteController extends StateNotifier<QuoteState> {
  QuoteController(this._ref) : super(const QuoteState()) {
    _engine = QuoteEngine(_ref);

    _ref.listen<ZohoMemberCustomerScope?>(zohoMemberCustomerScopeProvider, (
      ZohoMemberCustomerScope? previous,
      ZohoMemberCustomerScope? next,
    ) {
      final String prevKey = previous?.bindKey ?? '';
      final String nextKey = next?.bindKey ?? '';

      if (prevKey == nextKey) return;
      if (!_shouldAutoBindMemberCustomer) return;

      unawaited(_memberBinding.resolve(showError: false));
    });

    _ref.listen<QuoteContactPolicy>(quoteContactPolicyProvider, (
      QuoteContactPolicy? previous,
      QuoteContactPolicy next,
    ) {
      if (previous == next) return;
      if (!_shouldAutoBindMemberCustomer) return;

      unawaited(_memberBinding.resolve(showError: false));
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

  QuoteMemberBindingController get _memberBinding =>
      _ref.read(quoteMemberBindingControllerProvider);

  bool get _isMemberScoped => _policy == QuoteContactPolicy.memberScoped;

  bool get _shouldAutoBindMemberCustomer {
    if (!_isMemberScoped) return false;

    // Insurance is special: the quote customer must remain the insurer/payer
    // selected from the membership, not the logged-in member/customer.
    return !_meta.isInsurancePayment;
  }

  void setError(String? message) {
    final String msg = (message ?? '').trim();
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

  void patchDraft({
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
    DateTime? expiryDate,
    SalesDocumentAddress? deliveryAddress,
  }) {
    if (_busy) return;

    if (contact != null) _metaCtl.setContact(contact);
    if (reference != null) _metaCtl.setReference(reference);
    if (customerNotes != null) _metaCtl.setCustomerNotes(customerNotes);
    if (quoteDate != null) _metaCtl.setQuoteDate(quoteDate);
    if (expiryDate != null) _metaCtl.setExpiryDate(expiryDate);
    if (deliveryAddress != null) _metaCtl.setDeliveryAddress(deliveryAddress);
  }

  Future<void> ensureReady({
    String? editingQuoteId,
    required bool requirePrices,
  }) async {
    if (_busy) return;

    final String nextId = (editingQuoteId ?? '').trim();
    final String prevEditingId = (state.editingQuoteId ?? '').trim();
    final String prevLoadedId = (state.loadedEditId ?? '').trim();

    final bool shouldClearLines = _engine.shouldClearLinesOnSwitch(
      prevEditingId: prevEditingId.isEmpty ? null : prevEditingId,
      prevLoadedId: prevLoadedId.isEmpty ? null : prevLoadedId,
      nextEditingId: nextId,
    );

    if (nextId.isEmpty) {
      _metaCtl.beginNew();
      state = const QuoteState();

      if (_shouldAutoBindMemberCustomer) {
        unawaited(_memberBinding.resolve(showError: false));
      }

      await ensureDraftFromLines(requirePrices: requirePrices);
      return;
    }

    final bool switchingTarget =
        prevEditingId != nextId || prevLoadedId != nextId;

    if (switchingTarget) {
      _linesCtl.clear();
      _metaCtl.clearAll();
      _metaCtl.beginEdit(nextId);

      state = const QuoteState().copyWith(
        editingQuoteId: nextId,
        loadingEdit: true,
      );
    } else {
      if ((state.editingQuoteId ?? '').trim().isEmpty) {
        state = state.copyWith(editingQuoteId: nextId);
      }

      _metaCtl.beginEdit(nextId);
    }

    if (shouldClearLines) _linesCtl.clear();

    await ensureLoadedForEdit(nextId, requirePrices: requirePrices);
  }

  Future<void> ensureDraftFromLines({required bool requirePrices}) async {
    if (_busy) return;
    if (!requirePrices) return;

    final int missing = _engine.missingPriceLineCount();
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
    final String id = quoteId.trim();
    if (id.isEmpty) return;
    if (_busy && !state.loadingEdit) return;
    if ((state.loadedEditId ?? '').trim() == id) return;

    state = state.copyWith(
      loadingEdit: true,
      clearError: true,
      editingQuoteId: id,
    );

    try {
      final q = await _engine.loadQuote(id);

      _engine.setLinesFromZoho(q);

      final QuoteMetaState meta = _engine.metaFromZoho(q);

      _metaCtl.applyZohoMeta(
        editingQuoteId: id,
        contact: meta.contact,
        reference: meta.reference,
        customerNotes: meta.customerNotes,
        saleContext: meta.saleContext,
        paymentContext: meta.paymentContext,
        quoteDate: meta.quoteDate,
        expiryDate: meta.expiryDate,
        deliveryAddress: meta.deliveryAddress,
        patientSnapshot: meta.patientSnapshot,
        membershipId: meta.membershipId,
        prescriptionId: meta.prescriptionId,
        prescriptionLabel: meta.prescriptionLabel,
      );

      state = state.copyWith(loadingEdit: false, loadedEditId: id);

      await ensureDraftFromLines(requirePrices: requirePrices);
    } catch (e) {
      _failLoadingEdit(e);
    }
  }

  Future<String?> submit({required bool requirePrices}) async {
    if (_busy) return null;

    final QuoteMetaState metaBeforeBinding = _meta;

    final bool shouldBindMemberCustomer =
        _isMemberScoped && !metaBeforeBinding.isInsurancePayment;

    if (shouldBindMemberCustomer) {
      final ZohoContact? contact = await _memberBinding.resolve(
        showError: true,
      );

      if (contact == null) {
        SnackService.showError('Could not resolve your customer profile.');
        return null;
      }
    }

    final QuoteMetaState meta = _meta;

    final String? validationError = _engine.validateForSubmitV2(
      meta: meta,
      requirePrices: requirePrices,
      isEditing: state.isEditing,
    );

    if (validationError != null) {
      SnackService.showError(validationError);
      return null;
    }

    debugPrint(
      '[QuoteSubmit] '
      'sale=${meta.saleContext.apiValue} '
      'payment=${meta.effectivePaymentContext.apiValue} '
      'customerId=${meta.customerIdResolved} '
      'customer=${meta.contact?.title ?? ''} '
      'patient=${meta.resolvedPatientId ?? ''} '
      'membership=${meta.resolvedMembershipId ?? ''} '
      'prescription=${meta.resolvedPrescriptionId ?? ''}',
    );

    state = state.copyWith(
      submitting: true,
      clearError: true,
      clearLastCreatedId: true,
    );

    try {
      final QuoteDraft payload = _engine.buildPayloadDraftFromMeta(
        meta: meta,
        requirePrices: requirePrices,
      );

      if (state.isEditing) {
        return await _updateCurrentQuote(
          payload,
          quoteDate: meta.quoteDate,
          expiryDate: meta.expiryDate,
        );
      }

      return await _createQuote(
        payload,
        quoteDate: meta.quoteDate,
        expiryDate: meta.expiryDate,
      );
    } catch (e) {
      _failSubmitting(
        e,
        fallback: state.isEditing
            ? 'Failed to update quote'
            : 'Failed to create quote',
      );

      return null;
    }
  }

  Future<String?> _updateCurrentQuote(
    QuoteDraft payload, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async {
    final String id = (state.editingQuoteId ?? '').trim();

    if (id.isEmpty) {
      state = state.copyWith(submitting: false);
      SnackService.showError('Missing quote id');
      return null;
    }

    await _engine.update(
      id,
      payload,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    _invalidateQuoteCaches(id);

    state = state.copyWith(submitting: false);
    SnackService.showSuccess('Quote updated');

    return id;
  }

  Future<String?> _createQuote(
    QuoteDraft payload, {
    DateTime? quoteDate,
    DateTime? expiryDate,
  }) async {
    final created = await _engine.create(
      payload,
      quoteDate: quoteDate,
      expiryDate: expiryDate,
    );

    final String createdId = created.quoteId.trim();

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
  }

  Future<bool> deleteQuote(String quoteId) async {
    if (_busy) return false;

    final String id = quoteId.trim();
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
      _failSubmitting(e, fallback: 'Failed to delete quote');
      return false;
    }
  }

  Future<Uint8List?> getPdfBytes(String quoteId) async {
    if (_busy) return null;

    final String id = quoteId.trim();
    if (id.isEmpty) return null;

    state = state.copyWith(downloadingPdf: true, clearError: true);

    try {
      final Uint8List bytes = await _engine.getPdf(id);
      state = state.copyWith(downloadingPdf: false);
      return bytes;
    } catch (e) {
      _failDownloadingPdf(e);
      return null;
    }
  }

  Future<bool> emailQuote(String quoteId) async {
    if (_busy) return false;

    final String id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);

    try {
      await _engine.email(id);

      _invalidateQuoteCaches(id);

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Quote sent');

      return true;
    } catch (e) {
      _failSending(e, fallback: 'Failed to send quote');
      return false;
    }
  }

  Future<bool> markQuoteSent(String quoteId) async {
    if (_busy) return false;

    final String id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);

    try {
      await _engine.markSent(id);

      _invalidateQuoteCaches(id);

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Marked as sent');

      return true;
    } catch (e) {
      _failSending(e, fallback: 'Failed to mark as sent');
      return false;
    }
  }

  Future<QuoteConversionResult?> convertToInvoice(
    String quoteId, {
    DateTime? invoiceDate,
    DateTime? dueDate,
    String? membershipId,
    bool createInsuranceClaim = false,
    SalesDocumentPatientSnapshot? patientSnapshot,
    SalesDocumentAddress? deliveryAddress,
  }) async {
    if (_busy) return null;

    final String id = quoteId.trim();
    if (id.isEmpty) return null;

    state = state.copyWith(converting: true, clearError: true);

    try {
      final QuoteConversionResult result = await _engine.convertToInvoice(
        id,
        invoiceDate: invoiceDate,
        dueDate: dueDate,
        membershipId: membershipId,
        createInsuranceClaim: false,
        patientSnapshot: patientSnapshot,
        deliveryAddress: deliveryAddress,
      );

      _invalidateQuoteCaches(id);

      state = state.copyWith(converting: false);

      SnackService.showSuccess('Converted to invoice');

      return result;
    } catch (e) {
      _failConverting(e);
      return null;
    }
  }

  void _invalidateQuotesList() {
    for (final RetailDocScope scope in RetailDocScope.values) {
      _ref.invalidate(quotesListControllerProvider(scope));
    }
  }

  void _invalidateQuoteCaches(String quoteId) {
    final String id = quoteId.trim();
    if (id.isEmpty) return;

    _invalidateQuotesList();
    _ref.invalidate(zohoQuoteProvider(id));
  }

  String _friendlyError(Object error, {required String fallback}) {
    final String raw = error.toString().trim();
    if (raw.isEmpty) return fallback;

    final String cleaned = raw
        .replaceFirst(RegExp(r'^Exception:\s*'), '')
        .replaceFirst(RegExp(r'^StateError:\s*'), '')
        .replaceFirst(RegExp(r'^Bad state:\s*'), '')
        .trim();

    return cleaned.isEmpty ? fallback : cleaned;
  }

  void _failSubmitting(Object error, {required String fallback}) {
    final String message = _friendlyError(error, fallback: fallback);

    state = state.copyWith(submitting: false, error: message);
    SnackService.showError(message);
  }

  void _failLoadingEdit(Object error) {
    final String message = _friendlyError(
      error,
      fallback: 'Failed to load quote',
    );

    state = state.copyWith(loadingEdit: false, error: message);
    SnackService.showError(message);
  }

  void _failDownloadingPdf(Object error) {
    final String message = _friendlyError(
      error,
      fallback: 'Failed to load PDF',
    );

    state = state.copyWith(downloadingPdf: false, error: message);
    SnackService.showError(message);
  }

  void _failSending(Object error, {required String fallback}) {
    final String message = _friendlyError(error, fallback: fallback);

    state = state.copyWith(sending: false, error: message);
    SnackService.showError(message);
  }

  void _failConverting(Object error) {
    final String message = _friendlyError(
      error,
      fallback: 'Failed to convert to invoice',
    );

    state = state.copyWith(converting: false, error: message);
    SnackService.showError(message);
  }
}
