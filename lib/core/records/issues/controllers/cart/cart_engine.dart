import 'package:flutter_riverpod/flutter_riverpod.dart';

final cartEngineProvider = Provider<CartEngine>((ref) => CartEngine());

class CartEngine {
  Map<String, Map<String, int>> _clone(Map<String, Map<String, int>> current) {
    return {
      for (final e in current.entries) e.key: Map<String, int>.from(e.value),
    };
  }

  /// Set quantity for a (itemId, batchId) in the nested map.
  /// Removes empty item maps automatically when qty -> 0.
  Map<String, Map<String, int>> setQuantity({
    required Map<String, Map<String, int>> current,
    required String itemId,
    required String batchId,
    required int qty,
    int? maxQty,
  }) {
    final next = _clone(current);
    final clamped = qty.clamp(0, maxQty ?? qty);

    if (clamped == 0) {
      final perItem = Map<String, int>.from(next[itemId] ?? const {});
      perItem.remove(batchId);
      if (perItem.isEmpty) {
        next.remove(itemId);
      } else {
        next[itemId] = perItem;
      }
      return next;
    }

    final perItem = Map<String, int>.from(next[itemId] ?? const {});
    perItem[batchId] = clamped;
    next[itemId] = perItem;
    return next;
  }

  /// Remove a single batch row; prunes empty item entries.
  Map<String, Map<String, int>> removeBatch({
    required Map<String, Map<String, int>> current,
    required String itemId,
    required String batchId,
  }) {
    final next = _clone(current);
    final perItem = Map<String, int>.from(next[itemId] ?? const {});
    perItem.remove(batchId);
    if (perItem.isEmpty) {
      next.remove(itemId);
    } else {
      next[itemId] = perItem;
    }
    return next;
  }

  /// True if there are no quantities > 0.
  bool isEmpty(Map<String, Map<String, int>> current) {
    for (final perItem in current.values) {
      for (final q in perItem.values) {
        if (q > 0) return false;
      }
    }
    return true;
  }

  /// Sum of all quantities.
  int totalQuantity(Map<String, Map<String, int>> current) {
    var total = 0;
    for (final perItem in current.values) {
      for (final q in perItem.values) {
        total += q;
      }
    }
    return total;
  }
}
