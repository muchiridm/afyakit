import 'package:afyakit/shared/services/sku_batch_matcher.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/features/inventory/items/models/items/base_inventory_item.dart';

@immutable
class InventoryViewState {
  final ItemType itemType;
  final List<BaseInventoryItem> items;
  final List<BatchRecord> batches;
  final SkuBatchMatcher? matcher;
  final String query;
  final bool sortAscending;
  final bool isLoading;
  final String? error;

  const InventoryViewState({
    required this.itemType,
    required this.items,
    required this.batches,
    required this.matcher,
    required this.query,
    required this.sortAscending,
    required this.isLoading,
    this.error,
  });

  factory InventoryViewState.initialFor(ItemType type) => InventoryViewState(
    itemType: type,
    items: const [],
    batches: const [],
    matcher: null,
    query: '',
    sortAscending: true,
    isLoading: true,
    error: null,
  );

  InventoryViewState copyWith({
    ItemType? itemType,
    List<BaseInventoryItem>? items,
    List<BatchRecord>? batches,
    SkuBatchMatcher? matcher,
    String? query,
    bool? sortAscending,
    bool? isLoading,
    String? error,
  }) {
    return InventoryViewState(
      itemType: itemType ?? this.itemType,
      items: items ?? this.items,
      batches: batches ?? this.batches,
      matcher: matcher ?? this.matcher,
      query: query ?? this.query,
      sortAscending: sortAscending ?? this.sortAscending,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }

  bool get hasError => error != null && error!.isNotEmpty;
  bool get isEmpty => items.isEmpty;
}
