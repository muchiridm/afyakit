// lib/features/retail/catalog/controllers/cart_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/catalog/catalog_models.dart';

@immutable
class CartItem {
  const CartItem({required this.tile, required this.qty});

  final CatalogTile tile;
  final int qty;

  CartItem copyWith({CatalogTile? tile, int? qty}) {
    return CartItem(tile: tile ?? this.tile, qty: qty ?? this.qty);
  }
}

@immutable
class CartState {
  const CartState({required this.lines});

  final List<CartItem> lines;

  const CartState.empty() : lines = const <CartItem>[];

  bool get isEmpty => lines.isEmpty;
  bool get isNotEmpty => lines.isNotEmpty;

  /// Number of distinct lines (unique tiles).
  int get lineCount => lines.length;

  /// Total quantity across all lines.
  int get itemCount {
    var n = 0;
    for (final l in lines) {
      n += l.qty;
    }
    return n;
  }

  /// How many lines are missing a price.
  int get missingPriceLineCount {
    var n = 0;
    for (final l in lines) {
      if (l.tile.bestSellPrice == null) n++;
    }
    return n;
  }

  /// True if every line has a price.
  bool get hasAllPrices => missingPriceLineCount == 0;

  /// Estimated total using (price ?? 0).
  /// This is UI-only; Zoho is the source of truth for totals.
  num get estimatedTotal {
    num total = 0;
    for (final line in lines) {
      total += (line.tile.bestSellPrice ?? 0) * line.qty;
    }
    return total;
  }
}

class CartController extends StateNotifier<CartState> {
  CartController() : super(const CartState.empty());

  static const int _minQty = 1;
  static const int _maxQty = 9999;

  int _clampQty(int qty) => qty.clamp(_minQty, _maxQty);

  int _indexOf(String tileId) =>
      state.lines.indexWhere((l) => l.tile.id == tileId);

  CartItem? getLineByTileId(String tileId) {
    final idx = _indexOf(tileId);
    if (idx == -1) return null;
    return state.lines[idx];
  }

  int getQty(CatalogTile tile) {
    final idx = _indexOf(tile.id);
    if (idx == -1) return 0;
    return state.lines[idx].qty;
  }

  bool contains(CatalogTile tile) => _indexOf(tile.id) != -1;

  void addOrIncrement(CatalogTile tile, {int delta = 1}) {
    final idx = _indexOf(tile.id);

    // New line
    if (idx == -1) {
      final qty = _clampQty(delta < 1 ? 1 : delta);
      state = CartState(
        lines: <CartItem>[
          ...state.lines,
          CartItem(tile: tile, qty: qty),
        ],
      );
      return;
    }

    // Existing line
    final current = state.lines[idx];
    final nextQty = _clampQty(current.qty + delta);

    // If delta is 0 (or clamps to same value), avoid pointless state updates
    if (nextQty == current.qty) return;

    final nextLines = [...state.lines];
    nextLines[idx] = current.copyWith(qty: nextQty);
    state = CartState(lines: nextLines);
  }

  void setQty(CatalogTile tile, int qty) {
    final idx = _indexOf(tile.id);
    if (idx == -1) {
      // Optional: if someone sets qty > 0 for an item not yet in cart, add it.
      if (qty > 0) {
        final safe = _clampQty(qty);
        state = CartState(
          lines: <CartItem>[
            ...state.lines,
            CartItem(tile: tile, qty: safe),
          ],
        );
      }
      return;
    }

    if (qty <= 0) {
      remove(tile);
      return;
    }

    final safe = _clampQty(qty);
    final current = state.lines[idx];
    if (safe == current.qty) return;

    final nextLines = [...state.lines];
    nextLines[idx] = current.copyWith(qty: safe);
    state = CartState(lines: nextLines);
  }

  void updateQty(CatalogTile tile, int qty) => setQty(tile, qty);

  void decrement(CatalogTile tile, {int delta = 1}) {
    final idx = _indexOf(tile.id);
    if (idx == -1) return;

    final current = state.lines[idx];
    final nextQty = current.qty - (delta < 1 ? 1 : delta);

    if (nextQty <= 0) {
      remove(tile);
      return;
    }

    setQty(tile, nextQty);
  }

  void remove(CatalogTile tile) {
    final idx = _indexOf(tile.id);
    if (idx == -1) return;

    state = CartState(
      lines: state.lines
          .where((l) => l.tile.id != tile.id)
          .toList(growable: false),
    );
  }

  void clear() {
    if (state.lines.isEmpty) return;
    state = const CartState.empty();
  }
}

// Provider
final cartControllerProvider = StateNotifierProvider<CartController, CartState>(
  (ref) => CartController(),
);
