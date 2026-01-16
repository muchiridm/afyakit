import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/features/retail/catalog/catalog_models.dart';
import 'package:afyakit/features/retail/catalog/controllers/cart_controller.dart';
import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';

import 'package:afyakit/features/retail/sales/quotes/models/di_sales_tile.dart'; // reuse DiSalesTile
import 'package:afyakit/features/retail/sales/invoices/controllers/invoice_state.dart';
import 'package:afyakit/features/retail/sales/invoices/models/invoice_draft.dart';
import 'package:afyakit/features/retail/sales/invoices/services/zoho_invoices_service.dart';

import 'package:afyakit/shared/services/snack_service.dart';

final invoiceControllerProvider =
    StateNotifierProvider<InvoiceController, InvoiceState>(
      (ref) => InvoiceController(ref),
    );

class InvoiceController extends StateNotifier<InvoiceState> {
  InvoiceController(this._ref) : super(const InvoiceState());

  final Ref _ref;

  bool get _busy => state.submitting || state.loadingEdit;

  // ───────────────────────── Public API ─────────────────────────

  void setError(String? message) {
    final msg = (message ?? '').trim();
    state = state.copyWith(error: msg.isEmpty ? null : msg);
  }

  void reset() {
    if (_busy) return;
    state = const InvoiceState();
  }

  void cancelEdit() {
    if (_busy) return;
    state = const InvoiceState();
    SnackService.showSuccess('Edits cancelled');
  }

  Future<void> cancelAndStartNewFromCart({required bool requirePrices}) async {
    if (_busy) return;
    state = const InvoiceState();
    await ensureDraftFromCart(requirePrices: requirePrices);
  }

  /// - If [editingInvoiceId] provided => loads invoice and fills draft/date
  /// - Else => builds draft from cart
  ///
  /// ✅ Fix: switching EDIT → CREATE clears stale edit session and draft.
  Future<void> ensureReady({
    String? editingInvoiceId,
    required bool requirePrices,
  }) async {
    if (state.busy) return;

    final id = (editingInvoiceId ?? '').trim();
    final wantEdit = id.isNotEmpty;

    // ───────────────────────── CREATE requested ─────────────────────────
    if (!wantEdit) {
      final hadEditSession =
          (state.editingInvoiceId ?? '').trim().isNotEmpty ||
          (state.loadedEditId ?? '').trim().isNotEmpty;

      if (hadEditSession) {
        state = const InvoiceState();
      } else {
        if ((state.editingInvoiceId ?? '').trim().isNotEmpty ||
            (state.loadedEditId ?? '').trim().isNotEmpty) {
          state = const InvoiceState();
        }
      }

      await ensureDraftFromCart(requirePrices: requirePrices);
      return;
    }

    // ───────────────────────── EDIT requested ───────────────────────────
    if ((state.editingInvoiceId ?? '').trim() != id) {
      state = const InvoiceState();
      state = state.copyWith(editingInvoiceId: id);
    } else {
      if ((state.editingInvoiceId ?? '').trim().isEmpty) {
        state = state.copyWith(editingInvoiceId: id);
      }
    }

    await ensureLoadedForEdit(id, requirePrices: requirePrices);
  }

  /// One setter for everything “meta”.
  void patchDraft({
    ZohoContact? contact,
    String? reference,
    String? customerNotes,
    DateTime? invoiceDate,
    DateTime? dueDate,
  }) {
    if (_busy) return;

    var nextDraft = state.draft;
    var nextDate = state.invoiceDate;

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

    if (dueDate != null) {
      nextDraft = nextDraft.copyWith(
        dueDate: DateTime(dueDate.year, dueDate.month, dueDate.day),
      );
    }

    if (invoiceDate != null) {
      nextDate = DateTime(invoiceDate.year, invoiceDate.month, invoiceDate.day);
    }

    state = state.copyWith(
      clearError: true,
      draft: nextDraft,
      invoiceDate: nextDate,
    );
  }

  /// Returns the invoice id that should be opened next (created or edited).
  Future<String?> submit({required bool requirePrices}) async {
    if (_busy) return null;

    final isEdit = state.isEditing;
    final invoiceId = (state.editingInvoiceId ?? '').trim();

    if (!_validateDraft(requirePrices: requirePrices, isEdit: isEdit)) {
      return null;
    }

    state = state.copyWith(
      submitting: true,
      clearError: true,
      clearLastCreatedId: true,
    );

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);

      if (isEdit) {
        if (invoiceId.isEmpty) {
          state = state.copyWith(submitting: false);
          SnackService.showError('Missing invoice id');
          return null;
        }

        await svc.updateInvoiceFromDraft(
          invoiceId,
          state.draft,
          invoiceDate: state.invoiceDate,
        );

        state = state.copyWith(submitting: false);
        SnackService.showSuccess('Invoice updated');
        return invoiceId;
      }

      final createdId = await svc.createInvoiceIdFromDraft(
        state.draft,
        invoiceDate: state.invoiceDate,
      );

      // Clear cart after create
      _ref.read(cartControllerProvider.notifier).clear();

      final id = (createdId ?? '').trim();
      state = state.copyWith(
        submitting: false,
        lastCreatedInvoiceId: id.isEmpty ? null : id,
      );

      SnackService.showSuccess('Invoice created');
      return id.isEmpty ? null : id;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      SnackService.showError(
        state.isEditing
            ? 'Failed to update invoice'
            : 'Failed to create invoice',
      );
      return null;
    }
  }

  Future<bool> deleteInvoice(String invoiceId) async {
    if (_busy) return false;

    final id = invoiceId.trim();
    if (id.isEmpty) return false;

    state = state.copyWith(submitting: true, clearError: true);

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      await svc.delete(id);

      state = state.copyWith(submitting: false);
      SnackService.showSuccess('Invoice deleted');
      return true;
    } catch (e) {
      state = state.copyWith(submitting: false, error: e.toString());
      SnackService.showError('Failed to delete invoice');
      return false;
    }
  }

  // ───────────────────────── Create from cart ─────────────────────────

  Future<void> ensureDraftFromCart({required bool requirePrices}) async {
    if (_busy) return;

    final cart = _ref.read(cartControllerProvider);
    if (cart.lines.isEmpty) return;

    // Don't overwrite an existing draft (normal behavior).
    if (state.draft.lines.isNotEmpty) return;

    if (requirePrices) {
      final missing = cart.lines
          .where((l) => l.tile.bestSellPrice == null)
          .toList();
      if (missing.isNotEmpty) {
        SnackService.showError('Some items are missing price');
        return;
      }
    }

    final lines = cart.lines
        .map((l) {
          final t = l.tile;
          final num rate = (t.bestSellPrice ?? 0);
          final safeRate = rate < 0 ? 0 : rate;

          return InvoiceLineDraft(
            tile: _toDiSalesTile(t),
            quantity: l.qty < 1 ? 1 : l.qty,
            rate: safeRate,
            description: _lineDescriptionFor(t),
            lineItemId: null, // create-mode
          );
        })
        .toList(growable: false);

    state = state.copyWith(
      clearError: true,
      draft: state.draft.copyWith(lines: lines),
    );
  }

  // ───────────────────────── Edit load ─────────────────────────

  Future<void> ensureLoadedForEdit(
    String invoiceId, {
    required bool requirePrices,
  }) async {
    final id = invoiceId.trim();
    if (id.isEmpty) return;
    if (_busy) return;
    if (state.loadedEditId == id) return;

    state = state.copyWith(
      loadingEdit: true,
      clearError: true,
      editingInvoiceId: id,
    );

    try {
      final svc = await _ref.read(zohoInvoicesServiceProvider.future);
      final inv = await svc.getInvoice(id);

      final loadedDraft = _draftFromZohoInvoice(inv);
      final loadedDate = _invoiceDateFromZohoInvoice(inv) ?? state.invoiceDate;

      state = state.copyWith(
        loadingEdit: false,
        loadedEditId: id,
        invoiceDate: loadedDate,
        draft: loadedDraft,
      );
    } catch (e) {
      state = state.copyWith(loadingEdit: false, error: e.toString());
      SnackService.showError('Failed to load invoice');
    }
  }

  // ───────────────────────── Draft line edits (same ergonomics) ─────────────────────────

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

      final next = List<InvoiceLineDraft>.from(lines)
        ..add(
          InvoiceLineDraft(
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
      final next = List<InvoiceLineDraft>.from(lines)..removeAt(idx);
      state = state.copyWith(draft: state.draft.copyWith(lines: next));
      return;
    }

    final updated = lines[idx].copyWith(quantity: nextQty);
    final next = List<InvoiceLineDraft>.from(lines)..[idx] = updated;
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
    final next = List<InvoiceLineDraft>.from(lines)..[idx] = updated;

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
    final next = List<InvoiceLineDraft>.from(lines)..[idx] = updated;

    state = state.copyWith(draft: state.draft.copyWith(lines: next));
  }

  // ───────────────────────── Validation ─────────────────────────

  bool _validateDraft({required bool requirePrices, required bool isEdit}) {
    final draft = state.draft;

    if (draft.lines.isEmpty) {
      SnackService.showError(
        isEdit ? 'Invoice has no items' : 'Add at least one item',
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

    if (requirePrices) {
      final missing = draft.lines.where((l) => l.rate <= 0).toList();
      if (missing.isNotEmpty) {
        SnackService.showError('Some items are missing price');
        return false;
      }
    }

    return true;
  }

  // ───────────────────────── Helpers ─────────────────────────

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

  InvoiceDraft _draftFromZohoInvoice(Map<String, dynamic> inv) {
    final contactId = (inv['customer_id'] ?? '').toString().trim();
    final contactName = (inv['customer_name'] ?? '').toString().trim();

    final notes = (inv['notes'] ?? inv['customer_notes'] ?? '')
        .toString()
        .trim();

    final ref = (inv['reference_number'] ?? inv['reference'] ?? '')
        .toString()
        .trim();

    final currency = (inv['currency_code'] ?? '').toString().trim();

    // due_date lives on draft (nice to show/edit)
    final due = _parseZohoDate(inv['due_date']);

    final items = <InvoiceLineDraft>[];
    final raw = inv['line_items'];

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

        final canonKey = lineItemId.isNotEmpty
            ? lineItemId
            : (name.isNotEmpty ? name : 'line_${items.length + 1}');

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
          InvoiceLineDraft(
            tile: tile,
            quantity: safeQty,
            rate: safeRate,
            description: name.isEmpty ? null : name,
            lineItemId: lineItemId.isEmpty ? null : lineItemId,
          ),
        );
      }
    }

    return InvoiceDraft(
      contactId: contactId.isEmpty ? null : contactId,
      contactName: contactName.isEmpty ? null : contactName,
      customerNotes: notes.isEmpty ? null : notes,
      reference: ref.isEmpty ? null : ref,
      currencyCode: currency.isEmpty ? null : currency,
      dueDate: due,
      lines: items,
    );
  }

  DateTime? _invoiceDateFromZohoInvoice(Map<String, dynamic> inv) {
    final raw = inv['date'] ?? inv['invoice_date'] ?? inv['created_time'];
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
