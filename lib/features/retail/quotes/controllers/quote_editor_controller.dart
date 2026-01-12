// lib/features/retail/quotes/controllers/quote_editor_controller.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../contacts/models/zoho_contact.dart';

import '../controllers/quote_editor_state.dart';
import '../controllers/quote_hydrator.dart';
import '../extensions/quote_editor_mode_x.dart';
import '../models/di_sales_tile.dart';
import '../models/quote_draft.dart';
import '../services/di_sales_service.dart';
import '../services/zoho_quotes_service.dart';
import '../widgets/contact_picker_dialog.dart';

import 'quote_editor_engine.dart';

import 'package:afyakit/shared/services/dialog_service.dart';
import 'package:afyakit/shared/services/snack_service.dart';

final quoteEditorControllerProvider =
    StateNotifierProvider.autoDispose<QuoteEditorController, QuoteEditorState>(
      (ref) => QuoteEditorController(ref),
    );

class QuoteEditorController extends StateNotifier<QuoteEditorState> {
  QuoteEditorController(this._ref) : super(const QuoteEditorState());

  final Ref _ref;

  Timer? _debounce;
  int _token = 0;
  bool get _alive => mounted;

  @override
  void dispose() {
    _token++; // invalidate in-flight work
    _debounce?.cancel();
    _debounce = null;
    super.dispose();
  }

  // ───────────────────────── Internal helpers ─────────────────────────

  Future<QuoteEditorEngine> _engine() async {
    final quotes = await _ref.read(zohoQuotesServiceProvider.future);
    final sales = await _ref.read(diSalesServiceProvider.future);

    return QuoteEditorEngine(
      quotes: quotes,
      sales: sales,
      hydrator: const QuoteHydrator(),
    );
  }

  // ───────────────────────── Init ─────────────────────────

  Future<void> init({
    required QuoteEditorMode mode,
    String? quoteId,
    bool loadCatalog = true,
  }) async {
    if (!_alive) return;

    final id = (quoteId ?? '').trim();
    final myToken = ++_token;

    // Reset: mode is source of truth
    state = QuoteEditorState(
      mode: mode,
      quoteId: id.isEmpty ? null : id,
      customerId: null,
      customerName: null,
      currencyCode: null,
      draft: const QuoteDraft(),
      items: const <DiSalesTile>[],
      q: '',
      offset: 0,
      nextOffset: null,
      loadingCatalog: false,
      loadingQuote: false,
      savingQuote: false,
      error: null,
    );

    // Edit/preview must load quote first
    if (mode == QuoteEditorMode.edit || mode == QuoteEditorMode.preview) {
      if (id.isEmpty) {
        state = const QuoteEditorState(mode: QuoteEditorMode.create);
        return;
      }

      state = state.copyWith(
        loadingQuote: true,
        savingQuote: false,
        error: null,
        draft: const QuoteDraft(),
        clearCustomer: true,
      );

      try {
        final engine = await _engine();
        final hydrated = await engine.loadQuoteForEdit(id);

        if (!_alive || myToken != _token) return;

        state = state.copyWith(
          loadingQuote: false,
          draft: hydrated.draft,
          customerId: hydrated.customerId,
          customerName: hydrated.customerName,
          currencyCode: hydrated.currencyCode,
        );
      } catch (e) {
        if (!_alive || myToken != _token) return;
        state = state.copyWith(loadingQuote: false, error: e.toString());
        SnackService.showError('Failed to load quote');
        return;
      }
    }

    // Catalog load if mode wants it
    if (loadCatalog && state.mode.showCatalog) {
      await search(reset: true);
    }
  }

  // ─────────────────────── Catalog search (debounced) ───────────────────────

  void setQuery(String v) {
    if (!_alive) return;
    if (!state.mode.showCatalog) return;

    state = state.copyWith(q: v, error: null);

    _debounce?.cancel();
    final myToken = _token;

    _debounce = Timer(const Duration(milliseconds: 350), () {
      if (!_alive) return;
      if (myToken != _token) return;
      search(reset: true);
    });
  }

  Future<void> search({required bool reset}) async {
    if (!_alive) return;
    if (!state.mode.showCatalog) return;
    if (state.loadingCatalog) return; // avoid double fetches

    final myToken = _token;

    final q = state.q.trim();
    final offset = reset ? 0 : (state.nextOffset ?? 0);

    // on reset, nextOffset should be null until server responds
    state = state.copyWith(
      loadingCatalog: true,
      error: null,
      items: reset ? const <DiSalesTile>[] : state.items,
      offset: reset ? 0 : state.offset,
      nextOffset: reset ? null : state.nextOffset,
    );

    try {
      final engine = await _engine();

      final page = await engine.searchCatalog(
        q: q.isEmpty ? null : q,
        limit: 50,
        offset: offset,
      );

      if (!_alive || myToken != _token) return;

      final merged = reset
          ? page.items
          : <DiSalesTile>[...state.items, ...page.items];

      state = state.copyWith(
        loadingCatalog: false,
        items: merged,
        offset: page.offset,
        nextOffset: page.nextOffset, // null means “no more”
      );
    } catch (e) {
      if (!_alive || myToken != _token) return;
      state = state.copyWith(loadingCatalog: false, error: e.toString());
      SnackService.showError('Failed to load catalog');
    }
  }

  Future<void> loadMore() => search(reset: false);
  Future<void> refreshCatalog() => search(reset: true);

  // ─────────────────────── Draft ops (mode-aware) ───────────────────────

  void setContact(ZohoContact c) {
    if (!_alive) return;
    if (!state.mode.canPickContact) return;

    final id = c.contactId.trim();
    final name = c.displayName.trim();

    state = state.copyWith(
      draft: state.draft.copyWith(contact: c),
      customerId: id.isEmpty ? null : id,
      customerName: name.isEmpty ? null : name,
    );
  }

  void clearContact() {
    if (!_alive) return;
    if (!state.mode.canPickContact) return;

    state = state.copyWith(
      draft: state.draft.copyWith(clearContact: true),
      clearCustomer: true,
    );
  }

  void setReference(String v) {
    if (!_alive) return;
    if (!state.mode.canEditHeader) return;

    state = state.copyWith(draft: state.draft.copyWith(reference: v.trim()));
  }

  void setNotes(String v) {
    if (!_alive) return;
    if (!state.mode.canEditHeader) return;

    state = state.copyWith(draft: state.draft.copyWith(customerNotes: v));
  }

  /// ✅ Missing method (restored): add/merge a sales tile into draft lines
  void addTileToDraft(DiSalesTile t) {
    if (!_alive) return;
    if (!state.mode.canEditLines) return;

    // Merge by canonKey (fallback to title)
    final key = t.canonKey.trim().isEmpty ? t.tileTitle : t.canonKey;

    final idx = state.draft.lines.indexWhere((l) {
      final k2 = l.tile.canonKey.trim().isEmpty
          ? l.tile.tileTitle
          : l.tile.canonKey;
      return k2 == key;
    });

    final defaultRate = t.bestSellPrice ?? 0;

    if (idx == -1) {
      final line = QuoteLineDraft(tile: t, quantity: 1, rate: defaultRate);
      state = state.copyWith(
        draft: state.draft.copyWith(lines: [line, ...state.draft.lines]),
      );
      return;
    }

    final existing = state.draft.lines[idx];
    final updated = existing.copyWith(quantity: existing.quantity + 1);
    final next = [...state.draft.lines]..[idx] = updated;

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  /// ✅ Missing method (restored)
  void removeLine(int index) {
    if (!_alive) return;
    if (!state.mode.canEditLines) return;

    if (index < 0 || index >= state.draft.lines.length) return;
    final next = [...state.draft.lines]..removeAt(index);

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  /// ✅ Missing method (restored)
  void setLineQty(int index, int qty) {
    if (!_alive) return;
    if (!state.mode.canEditLines) return;

    final next = [...state.draft.lines];
    if (index < 0 || index >= next.length) return;

    final q = qty < 1 ? 1 : qty;
    next[index] = next[index].copyWith(quantity: q);

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  /// ✅ Missing method (restored)
  void setLineRate(int index, num rate) {
    if (!_alive) return;
    if (!state.mode.canEditLines) return;

    final next = [...state.draft.lines];
    if (index < 0 || index >= next.length) return;

    final r = rate < 0 ? 0 : rate;
    next[index] = next[index].copyWith(rate: r);

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  // ─────────────────────── UI flows ───────────────────────

  Future<void> openContactPicker() async {
    if (!state.mode.canPickContact) return;

    final picked = await DialogService.show<ZohoContact>(
      builder: (_) => ContactPickerDialog(ref: _ref),
    );

    if (picked != null) setContact(picked);
  }

  // ───────────────────────── Submit ─────────────────────────

  Future<void> submit() async {
    if (!_alive) return;

    final mode = state.mode;
    if (!mode.canSubmit) return;

    final d = state.draft;

    // Require contactId, not just contact object
    if (mode == QuoteEditorMode.create) {
      final cid = (d.contact?.contactId ?? '').trim();
      if (cid.isEmpty) {
        SnackService.showError('Pick a contact first');
        return;
      }
    }

    if (d.lines.isEmpty) {
      SnackService.showError('Add at least one item');
      return;
    }

    final myToken = _token;
    state = state.copyWith(savingQuote: true, error: null);

    try {
      final engine = await _engine();

      final out = await engine.save(
        mode: mode,
        quoteId: state.quoteId,
        draft: d,
      );

      if (!_alive || myToken != _token) return;

      state = state.copyWith(savingQuote: false);

      switch (out) {
        case QuoteSaveOk(:final updated):
          SnackService.showSuccess(updated ? 'Quote updated' : 'Quote created');
        case QuoteSaveFailed(:final message):
          state = state.copyWith(error: message);
          SnackService.showError('Failed to save quote');
      }
    } catch (e) {
      if (!_alive || myToken != _token) return;
      state = state.copyWith(savingQuote: false, error: e.toString());
      SnackService.showError('Failed to save quote');
    }
  }
}
