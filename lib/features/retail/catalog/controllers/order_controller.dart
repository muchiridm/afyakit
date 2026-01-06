// lib/core/catalog/controllers/quote_controller.dart

import 'package:afyakit/features/retail/catalog/catalog_models.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

@immutable
class OrderItem {
  final CatalogTile tile;
  final int qty;

  const OrderItem({required this.tile, required this.qty});

  OrderItem copyWith({CatalogTile? tile, int? qty}) =>
      OrderItem(tile: tile ?? this.tile, qty: qty ?? this.qty);
}

@immutable
class OrderState {
  final List<OrderItem> lines;

  const OrderState({required this.lines});

  const OrderState.empty() : lines = const [];

  bool get isEmpty => lines.isEmpty;

  num get estimatedTotal {
    num total = 0;
    for (final line in lines) {
      final price = line.tile.bestSellPrice;
      if (price != null) {
        total += price * line.qty;
      }
    }
    return total;
  }
}

class OrderController extends StateNotifier<OrderState> {
  OrderController() : super(const OrderState.empty());

  void addOrIncrement(CatalogTile tile, {int delta = 1}) {
    final idx = state.lines.indexWhere((l) => l.tile.id == tile.id);

    if (idx == -1) {
      state = OrderState(
        lines: [
          ...state.lines,
          OrderItem(tile: tile, qty: delta),
        ],
      );
    } else {
      final current = state.lines[idx];
      final newQty = (current.qty + delta).clamp(1, 9999);
      final updated = current.copyWith(qty: newQty);

      final newLines = [...state.lines];
      newLines[idx] = updated;
      state = OrderState(lines: newLines);
    }
  }

  void updateQty(CatalogTile tile, int qty) {
    if (qty <= 0) {
      remove(tile);
      return;
    }

    final idx = state.lines.indexWhere((l) => l.tile.id == tile.id);
    if (idx == -1) return;

    final current = state.lines[idx];
    final updated = current.copyWith(qty: qty);

    final newLines = [...state.lines];
    newLines[idx] = updated;
    state = OrderState(lines: newLines);
  }

  void remove(CatalogTile tile) {
    state = OrderState(
      lines: state.lines.where((l) => l.tile.id != tile.id).toList(),
    );
  }

  void clear() {
    state = const OrderState.empty();
  }
}

// Provider
final orderControllerProvider =
    StateNotifierProvider<OrderController, OrderState>(
      (ref) => OrderController(),
    );
