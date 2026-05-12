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

    _ref.listen<ZohoMemberCustomerScope?>(zohoMemberCustomerScopeProvider, (
      prev,
      next,
    ) {
      final p = prev?.bindKey ?? '';
      final n = next?.bindKey ?? '';
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
      // The UI can render immediately while the real Zoho contact is resolved
      // in the background.
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

    final scope = _ref.read(zohoMemberCustomerScopeProvider);

    final String acct = (scope?.accountNumber ?? '').trim();
    final String contactId = (scope?.contactId ?? '').trim();

    if (kDebugMode) {
      debugPrint(
        '[QuoteController.memberBind] '
        'acct=$acct '
        'contactId=$contactId '
        'scope=${scope?.debugLabel ?? 'null'}',
      );
    }

    if (acct.isEmpty) {
      if (showError) {
        SnackService.showError('Missing account scope.');
      }
      return;
    }

    final ZohoContact? current = _meta.contact;
    final String currentAcct = (current?.accountNumber ?? '').trim();
    final String currentContactId = (current?.contactId ?? '').trim();

    if (current != null) {
      if (contactId.isNotEmpty && currentContactId == contactId) {
        if (kDebugMode) {
          debugPrint(
            '[QuoteController.memberBind] already bound by contactId=$contactId',
          );
        }
        return;
      }

      if (currentAcct == acct) {
        if (kDebugMode) {
          debugPrint(
            '[QuoteController.memberBind] already bound by accountNumber=$acct',
          );
        }
        return;
      }
    }

    final String bindKey = contactId.isNotEmpty
        ? 'id:$contactId'
        : 'acct:$acct';

    final Future<void>? inFlight = _memberContactBindFuture;
    if (inFlight != null && _memberContactBindAcct == bindKey) {
      if (kDebugMode) {
        debugPrint(
          '[QuoteController.memberBind] reusing in-flight bind $bindKey',
        );
      }
      await inFlight;
      return;
    }

    late final Future<void> bindFuture;

    bindFuture = () async {
      try {
        final ZohoContactsService svc = await _ref.read(
          zohoContactsServiceProvider.future,
        );

        ZohoContact? best;

        // Fastest path:
        // Build a local customer contact from /auth/session/me immediately.
        // This avoids waiting for Zoho at screen open.
        if (contactId.isNotEmpty) {
          final ZohoContact? local = _ref.read(
            currentMemberZohoContactProvider,
          );

          if (local != null) {
            final String localAcct = (local.accountNumber ?? '').trim();
            final String localContactId = local.contactId.trim();

            if (localContactId == contactId && localAcct == acct) {
              best = local;

              if (kDebugMode) {
                debugPrint(
                  '[QuoteController.memberBind] optimistic local bind '
                  'contactId=${local.contactId} '
                  'acct=${local.accountNumber ?? ''} '
                  'title=${local.title}',
                );
              }

              // Refresh quietly; do not block the user.
              unawaited(
                _refreshMemberContactInBackground(
                  contactId: contactId,
                  accountNumber: acct,
                ),
              );
            }
          }

          // Network fast path:
          // Used only if local optimistic contact is unavailable.
          if (best == null) {
            if (kDebugMode) {
              debugPrint(
                '[QuoteController.memberBind] fast path LIGHT GET contactId=$contactId',
              );
            }

            final ZohoContact byId = await svc.getLight(contactId);

            final String byIdAcct = (byId.accountNumber ?? '').trim();
            final String byIdContactId = byId.contactId.trim();

            if (kDebugMode) {
              debugPrint(
                '[QuoteController.memberBind] fast path light result '
                'byIdContactId=$byIdContactId '
                'byIdAcct=$byIdAcct '
                'title=${byId.title}',
              );
            }

            if (byIdContactId != contactId) {
              if (showError) {
                SnackService.showError('Customer profile link is invalid.');
              }

              if (kDebugMode) {
                debugPrint(
                  '[QuoteController.memberBind] fast path rejected: '
                  'expected contactId=$contactId got=$byIdContactId',
                );
              }

              return;
            }

            if (byIdAcct.isNotEmpty && byIdAcct != acct) {
              if (showError) {
                SnackService.showError(
                  'Customer profile does not match your account.',
                );
              }

              if (kDebugMode) {
                debugPrint(
                  '[QuoteController.memberBind] fast path rejected: '
                  'expected acct=$acct got=$byIdAcct',
                );
              }

              return;
            }

            best = byId;
          }
        }

        // Fallback:
        // Only use the slow account-number lookup when /me has no zoho.contactId.
        if (best == null) {
          if (kDebugMode) {
            debugPrint(
              '[QuoteController.memberBind] fallback GET by accountNumber=$acct',
            );
          }

          best = await svc.getByAccountNumber(
            acct,
            type: ZohoContactTypeFilter.customerOnly,
          );
        }

        if (best == null) {
          if (showError) {
            SnackService.showError('Your customer profile is missing.');
          }

          if (kDebugMode) {
            debugPrint(
              '[QuoteController.memberBind] no customer profile found',
            );
          }

          return;
        }

        final String bestAcct = (best.accountNumber ?? '').trim();

        if (bestAcct.isNotEmpty && bestAcct != acct) {
          if (showError) {
            SnackService.showError(
              'Customer profile does not match your account.',
            );
          }

          if (kDebugMode) {
            debugPrint(
              '[QuoteController.memberBind] final account mismatch: '
              'expected acct=$acct got=$bestAcct',
            );
          }

          return;
        }

        final ZohoContact? latest = _meta.contact;
        final String latestAcct = (latest?.accountNumber ?? '').trim();
        final String latestContactId = (latest?.contactId ?? '').trim();

        if (latest != null) {
          if (contactId.isNotEmpty && latestContactId == contactId) return;
          if (latestAcct == acct) return;
        }

        _metaCtl.setContact(best);

        if (kDebugMode) {
          debugPrint(
            '[QuoteController.memberBind] bound customer '
            'contactId=${best.contactId} '
            'acct=${best.accountNumber ?? ''} '
            'title=${best.title}',
          );
        }
      } catch (e, st) {
        if (kDebugMode) {
          debugPrint('[QuoteController.memberBind] failed: $e');
          debugPrint('$st');
        }

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

    _memberContactBindAcct = bindKey;
    _memberContactBindFuture = bindFuture;

    await bindFuture;
  }

  Future<void> _refreshMemberContactInBackground({
    required String contactId,
    required String accountNumber,
  }) async {
    final String id = contactId.trim();
    final String acct = accountNumber.trim();

    if (id.isEmpty || acct.isEmpty) return;

    try {
      final ZohoContactsService svc = await _ref.read(
        zohoContactsServiceProvider.future,
      );

      final ZohoContact fresh = await svc.getLight(id);

      final String freshId = fresh.contactId.trim();
      final String freshAcct = (fresh.accountNumber ?? '').trim();

      if (freshId != id) return;
      if (freshAcct.isNotEmpty && freshAcct != acct) return;

      final ZohoContact? latest = _meta.contact;
      final String latestId = (latest?.contactId ?? '').trim();
      final String latestAcct = (latest?.accountNumber ?? '').trim();

      // Only patch if the same member contact is still selected.
      if (latestId == id || latestAcct == acct) {
        _metaCtl.setContact(fresh);

        if (kDebugMode) {
          debugPrint(
            '[QuoteController.memberBind] background refresh patched '
            'contactId=${fresh.contactId} '
            'acct=${fresh.accountNumber ?? ''} '
            'title=${fresh.title}',
          );
        }
      }
    } catch (e) {
      // Silent by design: optimistic contact is enough for UI.
      if (kDebugMode) {
        debugPrint(
          '[QuoteController.memberBind] background refresh failed: $e',
        );
      }
    }
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
