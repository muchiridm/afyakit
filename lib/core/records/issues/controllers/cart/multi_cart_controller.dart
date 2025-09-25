import 'package:afyakit/core/records/issues/controllers/cart/cart_engine.dart';
import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/records/issues/controllers/cart/cart_state.dart';
import 'package:afyakit/core/records/issues/controllers/cart/multi_cart_state.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';

import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/core/records/issues/models/view_models/cart_item_models.dart';
import 'package:afyakit/core/records/issues/services/cart_service.dart';

final multiCartProvider =
    StateNotifierProvider<MultiCartController, MultiCartState>(
      (ref) => MultiCartController(ref),
    );

class MultiCartController extends StateNotifier<MultiCartState> {
  final Ref ref;
  late final CartEngine _engine;

  MultiCartController(this.ref) : super(MultiCartState.empty()) {
    _engine = ref.read(cartEngineProvider);
  }

  // ─────────────────────────────────────────────────────────────
  // Internals & helpers (DRY)
  // ─────────────────────────────────────────────────────────────

  CartState _getOrCreateCart(String storeId, ItemType itemType) {
    final existing = state.cartsByStore[storeId];
    if (existing != null) return existing;
    return CartState.empty(itemType).copyWith(fromStore: storeId);
  }

  void _putCart(String storeId, CartState next) {
    state = state.copyWith(
      cartsByStore: {...state.cartsByStore, storeId: next},
    );
  }

  Map<String, Map<String, int>> _typedQty(Map<String, Map<String, int>> m) => {
    for (final e in m.entries) e.key: Map<String, int>.from(e.value),
  };

  void _updateCart(String storeId, CartState Function(CartState) fn) {
    final cart = state.cartFor(storeId);
    if (cart == null) return;
    _putCart(storeId, fn(cart));
  }

  void _applyToAll(CartState Function(CartState) fn) {
    final next = {
      for (final e in state.cartsByStore.entries) e.key: fn(e.value),
    };
    state = state.copyWith(cartsByStore: next);
  }

  // ─────────────────────────────────────────────────────────────
  // Quantity & item ops (delegates to CartEngine)
  // ─────────────────────────────────────────────────────────────

  void updateQuantity({
    required String itemId,
    required String batchId,
    required int qty,
    required String storeId,
    required ItemType itemType,
    int? maxQty,
  }) {
    final cart = _getOrCreateCart(storeId, itemType);
    final updatedMap = _engine.setQuantity(
      current: _typedQty(cart.batchQuantities),
      itemId: itemId,
      batchId: batchId,
      qty: qty,
      maxQty: maxQty,
    );
    _putCart(storeId, cart.copyWith(batchQuantities: updatedMap));
  }

  void remove({
    required String itemId,
    required String batchId,
    required String storeId,
  }) {
    final cart = state.cartFor(storeId);
    if (cart == null) return;

    final updatedMap = _engine.removeBatch(
      current: _typedQty(cart.batchQuantities),
      itemId: itemId,
      batchId: batchId,
    );
    _putCart(storeId, cart.copyWith(batchQuantities: updatedMap));
  }

  // ─────────────────────────────────────────────────────────────
  // Per-cart mutations
  // ─────────────────────────────────────────────────────────────

  void clearCart(String storeId) {
    final updated = {...state.cartsByStore}..remove(storeId);
    state = state.copyWith(cartsByStore: updated);
  }

  void setNote(String storeId, String note) =>
      _updateCart(storeId, (c) => c.copyWith(note: note));

  void setDestination(String storeId, String? dest) =>
      _updateCart(storeId, (c) => c.copyWith(destination: dest));

  void setType(String storeId, IssueType type) =>
      _updateCart(storeId, (c) => c.copyWith(type: type));

  void setDate(String storeId, DateTime date) =>
      _updateCart(storeId, (c) => c.copyWith(requestDate: date));

  void setItemType(String storeId, ItemType type) =>
      _updateCart(storeId, (c) => c.copyWith(itemType: type));

  // ─────────────────────────────────────────────────────────────
  // Bulk mutations (DRY via _applyToAll)
  // ─────────────────────────────────────────────────────────────

  void setTypeForAll(IssueType type) =>
      _applyToAll((c) => c.copyWith(type: type));

  void setDateForAll(DateTime date) =>
      _applyToAll((c) => c.copyWith(requestDate: date));

  void setDestinationForAll(String? destination) =>
      _applyToAll((c) => c.copyWith(destination: destination));

  void setNoteForAll(String note) => _applyToAll((c) => c.copyWith(note: note));

  void pruneEmptyCarts() {
    final next = <String, CartState>{};
    for (final e in state.cartsByStore.entries) {
      if (!_engine.isEmpty(_typedQty(e.value.batchQuantities))) {
        next[e.key] = e.value;
      }
    }
    state = state.copyWith(cartsByStore: next);
  }

  // ─────────────────────────────────────────────────────────────
  // Queries
  // ─────────────────────────────────────────────────────────────

  Map<String, int> getTotalQuantityPerStore() {
    final out = <String, int>{};
    for (final e in state.cartsByStore.entries) {
      out[e.key] = _engine.totalQuantity(_typedQty(e.value.batchQuantities));
    }
    return out;
  }

  // ─────────────────────────────────────────────────────────────
  // UI helpers (kept to avoid breaking widgets)
  // ─────────────────────────────────────────────────────────────

  List<CartDisplayItem> getDisplayItems(String storeId, Ref ref) {
    final cart = state.cartFor(storeId);
    if (cart == null) return [];
    return CartService(ref).getDisplayItems(cart.batchQuantities);
  }

  Map<String, List<CartDisplayItem>> getGroupedDisplayItems(Ref ref) {
    final grouped = <String, List<CartDisplayItem>>{};
    for (final entry in state.cartsByStore.entries) {
      final cart = entry.value;
      if (_engine.isEmpty(_typedQty(cart.batchQuantities))) continue;

      final items = CartService(ref).getDisplayItems(cart.batchQuantities);
      if (items.isNotEmpty) grouped[entry.key] = items;
    }
    return grouped;
  }

  List<Widget> getSummaryWidgetsFromEntries(Ref ref, List<IssueEntry> entries) {
    return [CartService(ref).buildSummaryFromEntries(entries)];
  }

  // ─────────────────────────────────────────────────────────────
  // Submission hook (optional wiring for single-cart submit)
  // ─────────────────────────────────────────────────────────────

  Future<bool> submitCart(
    BuildContext context,
    String storeId,
    CartState cart,
  ) async {
    // Hook IssueSubmitEngine here if you add single-cart submit.
    return true;
  }

  void clearAll() {
    state = state.copyWith(cartsByStore: {});
  }
}

// Keep this tiny forwarder and kill the manual construction
extension MultiCartDisplayExt on MultiCartController {
  Map<String, List<CartDisplayItem>> getDisplayGroups(Ref ref) {
    return getGroupedDisplayItems(ref);
  }
}
