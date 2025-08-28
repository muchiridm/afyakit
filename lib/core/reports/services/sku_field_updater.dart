import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/inventory/controllers/inventory_controller.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/reports/models/stock_report.dart';

class SkuFieldUpdater {
  final Ref ref;

  /// Pending updates: itemType → itemId → { field: value }
  final Map<ItemType, Map<String, Map<String, dynamic>>> pending = {};

  SkuFieldUpdater(this.ref);

  InventoryController get _controller =>
      ref.read(inventoryControllerProvider.notifier);

  // ─────────────────────────────────────────────────────────────────────────────
  // 🔧 Local Patch (in-memory + queue)
  // ─────────────────────────────────────────────────────────────────────────────

  StockReport? updateLocally({
    required List<StockReport> current,
    required String itemId,
    required String field,
    required dynamic value,
    required ItemType type,
    void Function(List<StockReport>)? onListUpdated,
  }) {
    if (field.trim().isEmpty || itemId.isEmpty) return null;

    final index = current.indexWhere((r) => r.itemId == itemId);
    if (index == -1) return null;

    final original = current[index];
    final updated = copyWithField(original, field, value);
    if (original == updated) return null;

    _queue(type, itemId, field, value);

    if (onListUpdated case final callback?) {
      final newList = [...current];
      newList[index] = updated;
      callback(newList);
    }

    return updated;
  }

  void _queue(ItemType type, String itemId, String field, dynamic value) {
    pending.putIfAbsent(type, () => {});
    pending[type]!.putIfAbsent(itemId, () => {});
    pending[type]![itemId]![field] = value;

    debugPrint('🛠 Queued [$itemId] → $field = $value');
  }

  // ─────────────────────────────────────────────────────────────────────────────
  // 🧠 Field-to-Model Translator
  // ─────────────────────────────────────────────────────────────────────────────

  StockReport copyWithField(StockReport r, String field, dynamic v) {
    switch (field) {
      case 'packSize':
        return r.copyWith(packSize: v.toString());
      case 'reorderLevel':
        return r.copyWith(reorderLevel: _tryInt(v));
      case 'proposedOrder':
        return r.copyWith(proposedOrder: _tryInt(v));
      case 'package':
        return r.copyWith(package: v.toString());
      default:
        return r;
    }
  }

  int? _tryInt(dynamic val) => val is int ? val : int.tryParse(val.toString());

  bool get hasPending => pending.values.any((e) => e.isNotEmpty);

  // ─────────────────────────────────────────────────────────────────────────────
  // 🚀 Flush (Backend Sync)
  // ─────────────────────────────────────────────────────────────────────────────

  Future<List<StockReport>> flush({bool log = true}) async {
    if (!hasPending) return [];

    final snapshot = Map.fromEntries(
      pending.entries.map((e) => MapEntry(e.key, Map.from(e.value))),
    );

    final List<StockReport> updatedReports = [];

    for (final type in snapshot.keys) {
      final items = snapshot[type]!;
      for (final itemId in items.keys) {
        final fields = items[itemId]!;
        final rawId = itemId.contains('__') ? itemId.split('__').last : itemId;

        try {
          final result = await _controller.updateFields(
            itemId: rawId,
            type: type,
            fields: fields,
          );

          if (log) {
            debugPrint('📥 Raw backend result for [$itemId]: $result');
          }

          // 🧱 Wrap this separately
          StockReport? updated;
          try {
            updated = StockReport.fromBackend(result);
            updatedReports.add(updated);
            if (log) {
              debugPrint('✅ Flushed [$itemId] → ${fields.entries}');
            }
          } catch (e, stack) {
            debugPrint('❌ Failed to parse StockReport.fromBackend: $e');
            debugPrint('📛 Crashing result: $result');
            debugPrint('📛 Stack trace: $stack');
          }
        } catch (e, stack) {
          debugPrint('❌ Failed to flush [$itemId]: $e');
          debugPrint('📛 Stack trace:\n$stack');
        }
      }
    }

    pending.clear();
    debugPrint('🧹 All pending updates flushed');

    return updatedReports;
  }

  /// Optional: Flush + patch into raw tab reports
  List<StockReport> patchRawReports({
    required List<StockReport> raw,
    required List<StockReport> flushed,
  }) {
    final updated = [...raw];

    for (final fresh in flushed) {
      final index = updated.indexWhere((r) => r.itemId == fresh.itemId);
      if (index != -1) updated[index] = fresh;
    }

    return updated;
  }

  void debugPending() {
    for (final entry in pending.entries) {
      final type = entry.key;
      for (final item in entry.value.entries) {
        debugPrint('🛠 [${type.name}] ${item.key}: ${item.value}');
      }
    }
  }
}
