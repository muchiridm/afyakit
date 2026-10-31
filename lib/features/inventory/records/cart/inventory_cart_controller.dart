import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory/batches/inventory_batch.dart';
import 'inventory_cart.dart';

/// Local staging only. The backend exclusively changes stock balances.
class InventoryCartController extends StateNotifier<InventoryCart> {
  InventoryCartController() : super(const InventoryCart());
  static int _sequence = 0;
  static String _newKey() =>
      'cart-${DateTime.now().toUtc().microsecondsSinceEpoch}-${++_sequence}';

  void select(InventoryBatch batch, int quantity) {
    if (state.isSubmitting) throw StateError('Issue is being submitted.');
    if (batch.isArchived) throw StateError('Archived batches cannot be issued.');
    if (batch.id.isEmpty || batch.itemId.isEmpty || batch.storeId.isEmpty) {
      throw const FormatException('Incomplete batch reference.');
    }
    if (state.storeId != null && state.storeId != batch.storeId && state.lines.isNotEmpty) {
      throw StateError('Complete or clear the current store cart first.');
    }
    if (quantity < 0 || quantity > batch.quantity || batch.quantity != batch.quantity.floorToDouble()) {
      throw RangeError('Quantity must be a whole number within the available balance.');
    }
    final lines = Map<String, InventoryCartLine>.from(state.lines);
    if (quantity == 0) {
      lines.remove(batch.id);
    } else {
      lines[batch.id] = InventoryCartLine.fromBatch(batch, quantity);
    }
    state = InventoryCart(
      storeId: lines.isEmpty ? null : batch.storeId,
      lines: Map.unmodifiable(lines), revision: state.revision + 1,
      requestKey: _newKey(),
    );
  }

  void remove(String batchId) {
    if (state.isSubmitting) throw StateError('Issue is being submitted.');
    if (!state.lines.containsKey(batchId)) return;
    final lines = Map<String, InventoryCartLine>.from(state.lines)..remove(batchId);
    state = InventoryCart(storeId: lines.isEmpty ? null : state.storeId,
      lines: Map.unmodifiable(lines), revision: state.revision + 1,
      requestKey: _newKey());
  }

  void clear() {
    if (state.isSubmitting) throw StateError('Issue is being submitted.');
    state = const InventoryCart();
  }

  void prepareSubmission(String fingerprint) {
    if (state.isSubmitting) throw StateError('Already submitting.');
    if (fingerprint != state.payloadFingerprint) {
      state = state.copyWith(requestKey: _newKey(), payloadFingerprint: fingerprint);
    }
  }

  void beginSubmission() {
    if (state.isSubmitting) throw StateError('Already submitting.');
    if (state.isEmpty) throw StateError('Cart is empty.');
    state = state.copyWith(isSubmitting: true);
  }

  /// Call on success only; failures retain the request key for safe retries.
  void submissionSucceeded() => state = const InventoryCart();
  void submissionFailed() => state = state.copyWith(isSubmitting: false);
}
