import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/features/retail/sales/quotes/controllers/quote_state.dart';

import 'package:afyakit/features/retail/catalog/catalog_models.dart';
import 'package:afyakit/features/retail/catalog/controllers/cart_controller.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';

import 'package:afyakit/features/retail/sales/quotes/models/di_sales_tile.dart';
import 'package:afyakit/features/retail/sales/quotes/models/quote_draft.dart';
import 'package:afyakit/features/retail/sales/quotes/services/zoho_quotes_service.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final quoteControllerProvider =
    StateNotifierProvider<QuoteController, QuoteState>(
      (ref) => QuoteController(ref),
    );

class QuoteController extends StateNotifier<QuoteState> {
  QuoteController(this._ref) : super(const QuoteState());

  final Ref _ref;

  bool get _busy => state.busy;

  // ───────────────────────── Public API ─────────────────────────

  void setError(String? message) {
    final msg = (message ?? '').trim();
    state = state.copyWith(error: msg.isEmpty ? null : msg);
  }

  void reset() {
    if (_busy) return;
    state = const QuoteState();
  }

  void cancelEdit() {
    if (_busy) return;
    state = const QuoteState();
    SnackService.showSuccess('Edits cancelled');
  }

  Future<void> cancelAndStartNewFromCart({required bool requirePrices}) async {
    if (_busy) return;
    state = const QuoteState();
    await ensureDraftFromCart(requirePrices: requirePrices);
  }

  Future<void> ensureReady({
    String? editingQuoteId,
    required bool requirePrices,
  }) async {
    if (state.busy) return;

    final id = (editingQuoteId ?? '').trim();
    final wantEdit = id.isNotEmpty;

    if (!wantEdit) {
      final hadEditSession =
          (state.editingQuoteId ?? '').trim().isNotEmpty ||
          (state.loadedEditId ?? '').trim().isNotEmpty;

      if (hadEditSession) {
        state = const QuoteState();
      } else {
        if ((state.editingQuoteId ?? '').trim().isNotEmpty ||
            (state.loadedEditId ?? '').trim().isNotEmpty) {
          state = const QuoteState();
        }
      }

      await ensureDraftFromCart(requirePrices: requirePrices);
      return;
    }

    if ((state.editingQuoteId ?? '').trim() != id) {
      state = const QuoteState();
      state = state.copyWith(editingQuoteId: id);
    } else {
      if ((state.editingQuoteId ?? '').trim().isEmpty) {
        state = state.copyWith(editingQuoteId: id);
      }
    }

    await ensureLoadedForEdit(id, requirePrices: requirePrices);
  }

  void patchDraft({
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    DateTime? quoteDate,
  }) {
    if (_busy) return;

    var nextDraft = state.draft;
    var nextDate = state.quoteDate;

    if (contact != null) {
      final customerId = contact.contactId.trim();
      final customerName = contact.title.trim();

      nextDraft = nextDraft.copyWith(
        contact: contact,
        contactId: customerId.isEmpty ? null : customerId,
        contactName: customerName.isEmpty ? null : customerName,
      );
    }

    if (reference != null) {
      nextDraft = nextDraft.copyWith(reference: _cleanOrNull(reference));
    }

    if (customerNotes != null) {
      nextDraft = nextDraft.copyWith(
        customerNotes: _cleanOrNull(customerNotes),
      );
    }

    if (quoteDate != null) {
      nextDate = DateTime(quoteDate.year, quoteDate.month, quoteDate.day);
    }

    state = state.copyWith(
      clearError: true,
      draft: nextDraft,
      quoteDate: nextDate,
    );
  }

  // ───────────────────────── NEW: Manual (non-catalog) lines ─────────────────────────

  /// Adds a new manual/custom line that is NOT tied to the catalog.
  /// The UI can then let the user edit name/qty/rate like normal.
  ///
  /// - `name` is optional; you can start empty and force user to type.
  /// - `qty` defaults to 1.
  /// - `rate` defaults to 0.
  void addManualLine({
    String? name,
    String? description,
    int qty = 1,
    num rate = 0,
  }) {
    if (_busy) return;

    final safeQty = qty < 1 ? 1 : qty;
    final safeRate = (rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate;

    final key = _newManualKey();

    final title = (name ?? '').trim();
    final desc = (description ?? '').trim();

    final tile = DiSalesTile(
      canonKey: key,
      groupKey: key,
      tileTitle: title, // can be empty; UI can show placeholder
      tileDesc: desc.isEmpty ? null : desc,
      form: null,
      bestPackCount: null,
      offerCount: 0,
      bestSellPrice: safeRate, // used as a sensible default
      bestSupplier: null,
      priceRequestRequired: null,
    );

    final line = QuoteLineDraft(
      tile: tile,
      quantity: safeQty,
      rate: safeRate,
      description: title.isEmpty ? null : title,
      lineItemId: null, // manual lines won't have Zoho line_item_id
    );

    final next = List<QuoteLineDraft>.from(state.draft.lines)..add(line);

    state = state.copyWith(
      clearError: true,
      draft: state.draft.copyWith(lines: next),
    );
  }

  /// Updates a manual/custom line by its canonKey.
  /// You can use this for an "Add custom product" dialog.
  void updateManualLine(
    String canonKey, {
    String? name,
    String? description,
    int? qty,
    num? rate,
  }) {
    if (_busy) return;

    final key = canonKey.trim();
    if (key.isEmpty) return;

    final lines = state.draft.lines;
    final idx = lines.indexWhere((l) => l.tile.canonKey.trim() == key);
    if (idx < 0) return;

    final cur = lines[idx];

    // Only intended for manual lines; guard to avoid accidentally overwriting catalog keys.
    if (!_isManualKey(cur.tile.canonKey)) {
      // Still allow name/desc edits, but keep it safe: only apply requested fields.
      // (This guard is optional; remove if you want to allow overwriting any line.)
    }

    final nextQty = qty == null ? cur.quantity : (qty < 1 ? 1 : qty);

    final nextRate = rate == null
        ? cur.rate
        : ((rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate);

    final nextName = name == null ? cur.description : _cleanOrNull(name);

    final nextDescRaw = (description ?? '').trim();
    final nextDesc = description == null
        ? cur.tile.tileDesc
        : (nextDescRaw.isEmpty ? null : nextDescRaw);

    // Update tile title too (so lists show it nicely)
    final newTitle = (name ?? cur.tile.tileTitle).trim();
    final tile = DiSalesTile(
      canonKey: cur.tile.canonKey,
      groupKey: cur.tile.groupKey,
      tileTitle: newTitle,
      tileDesc: nextDesc,
      form: cur.tile.form,
      bestPackCount: cur.tile.bestPackCount,
      offerCount: cur.tile.offerCount,
      bestSellPrice: cur.tile.bestSellPrice,
      bestSupplier: cur.tile.bestSupplier,
      priceRequestRequired: cur.tile.priceRequestRequired,
    );

    final updated = cur.copyWith(
      tile: tile,
      quantity: nextQty,
      rate: nextRate,
      description: nextName,
    );

    final next = List<QuoteLineDraft>.from(lines)..[idx] = updated;

    state = state.copyWith(
      clearError: true,
      draft: state.draft.copyWith(lines: next),
    );
  }

  // ───────────────────────── Submit / Delete ─────────────────────────

  Future<String?> submit({required bool requirePrices}) async {
    if (_busy) return null;

    final isEdit = state.isEditing;
    final quoteId = (state.editingQuoteId ?? '').trim();

    if (!_validateDraft(requirePrices: requirePrices, isEdit: isEdit)) {
      return null;
    }

    state = state.copyWith(
      submitting: true,
      clearError: true,
      clearLastCreatedId: true,
    );

    try {
      final svc = await _ref.read(zohoQuotesServiceProvider.future);

      if (isEdit) {
        if (quoteId.isEmpty) {
          state = state.copyWith(submitting: false);
          SnackService.showError('Missing quote id');
          return null;
        }

        await svc.updateQuoteFromDraft(
          quoteId,
          state.draft,
          quoteDate: state.quoteDate,
        );

        state = state.copyWith(submitting: false);
        SnackService.showSuccess('Quote updated');
        return quoteId;
      }

      final createdId = await svc.createQuoteIdFromDraft(
        state.draft,
        quoteDate: state.quoteDate,
      );

      _ref.read(cartControllerProvider.notifier).clear();

      final id = (createdId ?? '').trim();
      state = state.copyWith(
        submitting: false,
        lastCreatedQuoteId: id.isEmpty ? null : id,
      );

      SnackService.showSuccess('Quote created');
      return id.isEmpty ? null : id;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      SnackService.showError(
        state.isEditing ? 'Failed to update quote' : 'Failed to create quote',
      );
      return null;
    }
  }

  Future<bool> deleteQuote(String quoteId) async {
    if (_busy) return false;

    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(submitting: true, clearError: true);

    try {
      final svc = await _ref.read(zohoQuotesServiceProvider.future);
      await svc.delete(id);

      state = state.copyWith(submitting: false);
      SnackService.showSuccess('Quote deleted');
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      SnackService.showError('Failed to delete quote');
      return false;
    }
  }

  // ───────────────────────── PDF / SEND / CONVERT ─────────────────────────

  Future<Uint8List?> getPdfBytes(String quoteId) async {
    if (_busy) return null;

    final id = quoteId.trim();
    if (id.isEmpty) return null;

    state = state.copyWith(downloadingPdf: true, clearError: true);

    try {
      final svc = await _ref.read(zohoQuotesServiceProvider.future);
      final bytes = await svc.getPdf(id);

      state = state.copyWith(downloadingPdf: false);
      return bytes;
    } catch (e) {
      state = state.copyWith(downloadingPdf: false, error: e.toString());
      SnackService.showError('Failed to load PDF');
      return null;
    }
  }

  Future<bool> sendQuote(String quoteId) async {
    if (_busy) return false;

    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);

    try {
      final svc = await _ref.read(zohoQuotesServiceProvider.future);
      await svc.sendQuote(id);

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
      final svc = await _ref.read(zohoQuotesServiceProvider.future);
      await svc.markQuoteSent(id);

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Marked as sent');
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
      SnackService.showError('Failed to mark quote as sent');
      return false;
    }
  }

  Future<bool> sendAndMarkSent(String quoteId) async {
    if (_busy) return false;

    final id = quoteId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(sending: true, clearError: true);

    try {
      final svc = await _ref.read(zohoQuotesServiceProvider.future);
      await svc.sendAndMarkSent(id);

      state = state.copyWith(sending: false);
      SnackService.showSuccess('Quote sent & marked sent');
      return true;
    } catch (e) {
      state = state.copyWith(sending: false, error: e.toString());
      SnackService.showError('Failed to send quote');
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
      final svc = await _ref.read(zohoQuotesServiceProvider.future);
      final res = await svc.convertToInvoice(
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

  // ───────────────────────── Existing flows (kept) ─────────────────────────

  Future<void> ensureDraftFromCart({required bool requirePrices}) async {
    if (_busy) return;

    final cart = _ref.read(cartControllerProvider);
    if (cart.lines.isEmpty) return;

    // Don't overwrite an already-started draft
    if (state.draft.lines.isNotEmpty) return;

    int missingPriceCount = 0;

    for (final l in cart.lines) {
      if (l is CatalogCartLine) {
        if (l.tile.bestSellPrice == null) missingPriceCount++;
      } else if (l is ManualCartLine) {
        if (l.rate <= 0) missingPriceCount++;
      }
    }

    if (missingPriceCount > 0) {
      SnackService.showInfo(
        '$missingPriceCount item(s) missing price — you can enter prices manually.',
      );
    }

    final lines = cart.lines
        .map((l) {
          // ── Catalog line ─────────────────────────────
          if (l is CatalogCartLine) {
            final t = l.tile;
            final num rate = (t.bestSellPrice ?? 0);
            final safeRate = rate < 0 ? 0 : rate;

            return QuoteLineDraft(
              tile: _toDiSalesTile(t),
              quantity: l.qty < 1 ? 1 : l.qty,
              rate: safeRate,
              description: _lineDescriptionFor(t),
              lineItemId: null,
            );
          }

          // ── Manual line ──────────────────────────────
          final m = l as ManualCartLine;

          final safeQty = m.qty < 1 ? 1 : m.qty;
          final safeRate = (m.rate.isNaN || m.rate.isInfinite || m.rate < 0)
              ? 0
              : m.rate;

          final safeName = m.name.trim().isEmpty ? 'Item' : m.name.trim();
          final safeDesc = (m.description ?? '').trim().isEmpty
              ? null
              : m.description!.trim();

          // This tile is a "fallback" tile used only for quote lines
          // canonKey/groupKey must be stable so edits target the same line.
          final tile = DiSalesTile.fallbackFromName(
            name: safeName,
            description: safeDesc,
            canonKey: m.manualId,
            groupKey: m.manualId,
          );

          return QuoteLineDraft(
            tile: tile,
            quantity: safeQty,
            rate: safeRate,
            description: safeName, // what appears as Zoho "name"
            lineItemId: null,
          );
        })
        .toList(growable: false);

    state = state.copyWith(
      clearError: true,
      draft: state.draft.copyWith(lines: lines),
    );
  }

  Future<void> ensureLoadedForEdit(
    String quoteId, {
    required bool requirePrices,
  }) async {
    final id = quoteId.trim();
    if (id.isEmpty) return;
    if (_busy) return;
    if (state.loadedEditId == id) return;

    state = state.copyWith(
      loadingEdit: true,
      clearError: true,
      editingQuoteId: id,
    );

    try {
      final svc = await _ref.read(zohoQuotesServiceProvider.future);

      final q = await svc.getQuote(id);

      final loadedDraft = _draftFromZohoQuote(q);
      final loadedDate = _quoteDateFromZohoQuote(q) ?? state.quoteDate;

      state = state.copyWith(
        loadingEdit: false,
        loadedEditId: id,
        quoteDate: loadedDate,
        draft: loadedDraft,
      );
    } catch (e) {
      state = state.copyWith(loadingEdit: false, error: e.toString());
      SnackService.showError('Failed to load quote');
    }
  }

  void updateDraftQty(DiSalesTile tile, int qty) {
    if (_busy) return;

    final nextQty = qty < 0 ? 0 : qty;
    final lines = state.draft.lines;

    final key = tile.canonKey.trim();
    final idx = lines.indexWhere((l) => l.tile.canonKey.trim() == key);

    if (idx < 0) {
      if (nextQty == 0) return;

      final rate = tile.bestSellPrice ?? 0;
      final safeRate = rate < 0 ? 0 : rate;

      final next = List<QuoteLineDraft>.from(lines)
        ..add(
          QuoteLineDraft(
            tile: tile,
            quantity: nextQty,
            rate: safeRate,
            lineItemId: null,
          ),
        );

      state = state.copyWith(draft: state.draft.copyWith(lines: next));
      return;
    }

    if (nextQty == 0) {
      final next = List<QuoteLineDraft>.from(lines)..removeAt(idx);
      state = state.copyWith(draft: state.draft.copyWith(lines: next));
      return;
    }

    final updated = lines[idx].copyWith(quantity: nextQty);
    final next = List<QuoteLineDraft>.from(lines)..[idx] = updated;
    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  void updateDraftRate(DiSalesTile tile, num rate) {
    if (_busy) return;

    final lines = state.draft.lines;
    final key = tile.canonKey.trim();
    final idx = lines.indexWhere((l) => l.tile.canonKey.trim() == key);
    if (idx < 0) return;

    final safe = (rate.isNaN || rate.isInfinite || rate < 0) ? 0 : rate;
    final updated = lines[idx].copyWith(rate: safe);
    final next = List<QuoteLineDraft>.from(lines)..[idx] = updated;

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  void updateDraftName(DiSalesTile tile, String name) {
    if (_busy) return;

    final v = name.trim();
    if (v.isEmpty) return;
    if (v.toLowerCase() == 'item') return;

    final lines = state.draft.lines;
    final key = tile.canonKey.trim();
    final idx = lines.indexWhere((l) => l.tile.canonKey.trim() == key);
    if (idx < 0) return;

    final updated = lines[idx].copyWith(description: v);
    final next = List<QuoteLineDraft>.from(lines)..[idx] = updated;

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  // ───────────────────────── Validation ─────────────────────────

  bool _validateDraft({required bool requirePrices, required bool isEdit}) {
    final draft = state.draft;

    if (draft.lines.isEmpty) {
      SnackService.showError(
        isEdit ? 'Quote has no items' : 'Add at least one item',
      );
      return false;
    }

    if (!isEdit) {
      final customerId = (draft.contactId ?? draft.contact?.contactId ?? '')
          .trim();
      if (customerId.isEmpty) {
        SnackService.showError('Please pick a customer');
        return false;
      }
    }

    // ✅ Manual lines must have some kind of name.
    final unnamed = draft.lines.where((l) {
      final name = (l.description ?? l.tile.tileTitle).trim();
      return name.isEmpty;
    }).toList();
    if (unnamed.isNotEmpty) {
      SnackService.showError(
        'Some items are missing a name. Please edit them.',
      );
      return false;
    }

    if (requirePrices) {
      final missing = draft.lines.where((l) => l.rate <= 0).toList();
      if (missing.isNotEmpty) {
        SnackService.showInfo(
          '${missing.length} item(s) have no price — you can submit, but remember to set prices.',
        );
      }
    }

    return true;
  }

  // ───────────────────────── Helpers ─────────────────────────

  String _newManualKey() {
    // Unique-enough key for a draft session. No imports needed.
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return 'manual_$stamp';
  }

  bool _isManualKey(String canonKey) => canonKey.trim().startsWith('manual_');

  static String? _cleanOrNull(String? v) {
    final t = (v ?? '').trim();
    return t.isEmpty ? null : t;
  }

  static String _lineDescriptionFor(CatalogTile t) {
    final title = (t.tileTitle ?? '').trim();
    if (title.isNotEmpty) return title;

    final brand = t.brand.trim();
    final strength = t.strengthSig.trim();
    final form = t.form.trim();

    final parts = <String>[
      if (brand.isNotEmpty) brand,
      if (strength.isNotEmpty) strength,
      if (form.isNotEmpty) form,
      if ((t.packsFmt ?? '').trim().isNotEmpty) t.packsFmt!.trim(),
    ];

    if (parts.isNotEmpty) return parts.join(' • ');

    final desc = (t.tileDesc ?? '').trim();
    return desc.isNotEmpty ? desc : '';
  }

  DiSalesTile _toDiSalesTile(CatalogTile t) {
    final tileTitle = (t.tileTitle ?? t.brand).trim();
    final safeTitle = tileTitle.isEmpty ? t.brand : tileTitle;

    return DiSalesTile(
      canonKey: t.id,
      groupKey: t.id,
      tileTitle: safeTitle,
      tileDesc: (t.tileDesc ?? '').trim().isEmpty ? null : t.tileDesc,
      form: t.form.trim().isEmpty ? null : t.form,
      bestPackCount: t.bestPackCount,
      offerCount: t.offerCount ?? 0,
      bestSellPrice: t.bestSellPrice,
      bestSupplier: (t.bestSupplier ?? '').trim().isNotEmpty
          ? t.bestSupplier!.trim()
          : null,
      priceRequestRequired: null,
    );
  }

  QuoteDraft _draftFromZohoQuote(Map<String, dynamic> q) {
    final contactId = (q['customer_id'] ?? '').toString().trim();
    final contactName = (q['customer_name'] ?? '').toString().trim();

    final notes = (q['notes'] ?? q['customer_notes'] ?? '').toString().trim();
    final ref = (q['reference_number'] ?? q['reference'] ?? '')
        .toString()
        .trim();
    final currency = (q['currency_code'] ?? '').toString().trim();

    final items = <QuoteLineDraft>[];
    final raw = q['line_items'];

    if (raw is List) {
      for (final it in raw) {
        if (it is! Map) continue;
        final m = it.cast<String, dynamic>();

        final lineItemId = (m['line_item_id'] ?? '').toString().trim();

        final rawName = (m['name'] ?? '').toString().trim();
        final name = rawName.toLowerCase() == 'item' ? '' : rawName;

        final zohoDesc = (m['description'] ?? '').toString().trim();
        final safeDesc = zohoDesc.isEmpty ? null : zohoDesc;

        final qty = _asInt(m['quantity']) ?? 1;
        final rate = _asNum(m['rate']) ?? 0;

        final safeQty = qty < 1 ? 1 : qty;
        final safeRate = rate < 0 ? 0 : rate;

        // For non-catalog lines coming from Zoho, we still give them a stable key.
        final canonKey = lineItemId.isNotEmpty
            ? lineItemId
            : (name.isNotEmpty
                  ? 'manual_${name}_${items.length + 1}'
                  : _newManualKeyStatic(items.length));

        final tile = DiSalesTile(
          canonKey: canonKey,
          groupKey: canonKey,
          tileTitle: name,
          tileDesc: safeDesc,
          form: null,
          bestPackCount: null,
          offerCount: 0,
          bestSellPrice: safeRate,
          bestSupplier: null,
          priceRequestRequired: null,
        );

        items.add(
          QuoteLineDraft(
            tile: tile,
            quantity: safeQty,
            rate: safeRate,
            description: name.isEmpty ? null : name,
            lineItemId: lineItemId.isEmpty ? null : lineItemId,
          ),
        );
      }
    }

    return QuoteDraft(
      contactId: contactId.isEmpty ? null : contactId,
      contactName: contactName.isEmpty ? null : contactName,
      customerNotes: notes.isEmpty ? null : notes,
      reference: ref.isEmpty ? null : ref,
      currencyCode: currency.isEmpty ? null : currency,
      lines: items,
    );
  }

  // ───────────────────────── Manual/custom lines ─────────────────────────

  /// Adds a blank/manual line that does NOT come from catalog.
  /// User can rename it using edit-name UI.
  void addCustomLine({String? name}) {
    if (_busy) return;

    final now = DateTime.now().microsecondsSinceEpoch;
    final key = 'manual_$now';

    final safeName = (name ?? '').trim();
    final title = safeName.isEmpty ? 'Custom item' : safeName;

    final tile = DiSalesTile.fallbackFromName(
      name: title,
      description: null,
      canonKey: key,
      groupKey: key,
    );

    final nextLine = QuoteLineDraft(
      tile: tile,
      quantity: 1,
      rate: 0,
      description: title, // becomes Zoho "name" in your payload
      lineItemId: null,
    );

    final nextDraft = state.draft.upsertLine(nextLine);
    state = state.copyWith(clearError: true, draft: nextDraft);
  }

  // Helper for static creation in _draftFromZohoQuote without accessing instance methods.
  static String _newManualKeyStatic(int n) {
    final stamp = DateTime.now().microsecondsSinceEpoch;
    return 'manual_${stamp}_$n';
  }

  DateTime? _quoteDateFromZohoQuote(Map<String, dynamic> q) {
    final raw =
        q['date'] ?? q['estimate_date'] ?? q['quote_date'] ?? q['created_time'];
    return _parseZohoDate(raw);
  }

  DateTime? _parseZohoDate(Object? v) {
    if (v == null) return null;

    final s0 = v.toString().trim();
    if (s0.isEmpty) return null;

    if (RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s0)) {
      final d = DateFormat('yyyy-MM-dd').parseStrict(s0);
      return DateTime(d.year, d.month, d.day);
    }

    final tzFix = RegExp(r'([+-]\d{2})(\d{2})$');
    final s = s0.replaceFirstMapped(tzFix, (m) => '${m[1]}:${m[2]}');

    final dt = DateTime.tryParse(s);
    return dt?.toLocal();
  }

  static num? _asNum(Object? v) {
    if (v is num) return v;
    if (v is String) return num.tryParse(v.trim());
    return num.tryParse(v.toString());
  }

  static int? _asInt(Object? v) {
    final n = _asNum(v);
    if (n == null) return null;
    return n.round();
  }
}
