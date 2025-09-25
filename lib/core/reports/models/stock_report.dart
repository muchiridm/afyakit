import 'dart:developer';

import 'package:afyakit/core/batches/models/batch_record.dart';
import 'package:afyakit/core/inventory/models/items/base_inventory_item.dart';
import 'package:afyakit/core/inventory/models/items/consumable_item.dart';
import 'package:afyakit/core/inventory/models/items/equipment_item.dart';
import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/inventory/models/items/medication_item.dart';
import 'package:afyakit/shared/utils/parsers/int_parser.dart';
import 'package:flutter/foundation.dart';

class StockReport {
  final String itemId;
  final ItemType itemType;
  final String name;
  final String group;
  final String storeId;

  final int quantity;
  final List<DateTime>? expiryDates;
  final List<String>? stores;

  final int? reorderLevel;
  final int? proposedOrder;

  final String? brandName;
  final String? strength;
  final String? size;
  final List<String>? route;
  final String? formulation;
  final String? packSize;

  final String? description;
  final String? unit;
  final String? package;

  final String? model;
  final String? manufacturer;
  final String? serialNumber;

  const StockReport({
    required this.itemId,
    required this.itemType,
    required this.name,
    required this.group,
    required this.storeId,
    required this.quantity,
    this.expiryDates,
    this.stores,
    this.reorderLevel,
    this.proposedOrder,
    this.brandName,
    this.strength,
    this.size,
    this.route,
    this.formulation,
    this.packSize,
    this.description,
    this.unit,
    this.package,
    this.model,
    this.manufacturer,
    this.serialNumber,
  });

  /// Centralized report constructor — works for all modes.
  static StockReport fromItemWithQuantity(
    BaseInventoryItem item, {
    required String storeId,
    required int quantity,
    List<DateTime>? expiryDates,
    List<String>? stores,
  }) {
    final itemId = item.id;
    if (itemId == null || itemId.isEmpty) {
      throw ArgumentError('Item is missing an ID.');
    }

    final namespacedId = '${item.type.name}__$itemId';

    return StockReport(
      itemId: namespacedId,
      itemType: item.type,
      name: item.name,
      group: item.group,
      storeId: storeId,
      quantity: quantity,
      expiryDates: expiryDates,
      stores: stores,
      reorderLevel: item.reorderLevel,
      proposedOrder: item.proposedOrder,
      brandName: switch (item) {
        MedicationItem() => item.brandName,
        ConsumableItem() => item.brandName,
        _ => null,
      },
      strength: switch (item) {
        MedicationItem() => item.strength,
        _ => null,
      },
      size: switch (item) {
        MedicationItem() => item.size,
        ConsumableItem() => item.size,
        _ => null,
      },
      route: switch (item) {
        MedicationItem() => item.route,
        _ => null,
      },
      formulation: switch (item) {
        MedicationItem() => item.formulation,
        _ => null,
      },
      packSize: switch (item) {
        MedicationItem() => item.packSize,
        ConsumableItem() => item.packSize,
        _ => null,
      },
      description: switch (item) {
        ConsumableItem() => item.description,
        EquipmentItem() => item.description,
        _ => null,
      },
      unit: switch (item) {
        ConsumableItem() => item.unit,
        _ => null,
      },
      package: switch (item) {
        ConsumableItem() => item.package,
        EquipmentItem() => item.package,
        _ => null,
      },
      model: switch (item) {
        EquipmentItem() => item.model,
        _ => null,
      },
      manufacturer: switch (item) {
        EquipmentItem() => item.manufacturer,
        _ => null,
      },
      serialNumber: switch (item) {
        EquipmentItem() => item.serialNumber,
        _ => null,
      },
    );
  }

  /// Used when generating reports from batch data
  static StockReport fromBatchRecord({
    required BaseInventoryItem item,
    required BatchRecord batch,
  }) {
    return StockReport.fromItemWithQuantity(
      item,
      storeId: batch.storeId,
      quantity: batch.quantity,
      expiryDates: [if (batch.expiryDate != null) batch.expiryDate!],
    );
  }

  StockReport copyWith({
    String? itemId,
    ItemType? itemType,
    String? name,
    String? group,
    String? storeId,
    int? quantity,
    List<DateTime>? expiryDates,
    List<String>? stores,
    int? reorderLevel,
    int? proposedOrder,
    String? brandName,
    String? strength,
    String? size,
    List<String>? route,
    String? formulation,
    String? packSize,
    String? description,
    String? unit,
    String? package,
    String? model,
    String? manufacturer,
    String? serialNumber,
  }) {
    return StockReport(
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      name: name ?? this.name,
      group: group ?? this.group,
      storeId: storeId ?? this.storeId,
      quantity: quantity ?? this.quantity,
      expiryDates: expiryDates ?? this.expiryDates,
      stores: stores ?? this.stores,
      reorderLevel: reorderLevel ?? this.reorderLevel,
      proposedOrder: proposedOrder ?? this.proposedOrder,
      brandName: brandName ?? this.brandName,
      strength: strength ?? this.strength,
      size: size ?? this.size,
      route: route ?? this.route,
      formulation: formulation ?? this.formulation,
      packSize: packSize ?? this.packSize,
      description: description ?? this.description,
      unit: unit ?? this.unit,
      package: package ?? this.package,
      model: model ?? this.model,
      manufacturer: manufacturer ?? this.manufacturer,
      serialNumber: serialNumber ?? this.serialNumber,
    );
  }

  factory StockReport.fromBackend(Map<String, dynamic> data) {
    final rawId = data['id'] as String? ?? '';
    final itemType = ItemType.fromString(data['itemType'] ?? 'unknown');

    // 🪵 Log raw input (guarded to avoid spam)
    if (kDebugMode) {
      log('[fromBackend] Raw data: $data');
    }

    try {
      return StockReport(
        itemId: '${itemType.name}__$rawId',
        itemType: itemType,
        name: data['name'] ?? '',
        group: data['group'] ?? '',
        storeId: data['storeId'] ?? '',
        quantity: parseInt(data['quantity']) ?? 0, // 💥 protect this!
        reorderLevel: parseInt(data['reorderLevel']),
        proposedOrder: parseInt(data['proposedOrder']),
        brandName: data['brandName'],
        strength: data['strength'],
        size: data['size'],
        route: (data['route'] as List?)?.cast<String>(),
        formulation: data['formulation'],
        packSize: data['packSize'],
        description: data['description'],
        unit: data['unit'],
        package: data['package'],
        model: data['model'],
        manufacturer: data['manufacturer'],
        serialNumber: data['serialNumber'],
      );
    } catch (e, stack) {
      // 🧨 Log error and rethrow
      log('❌ Failed to parse StockReport: $e\n$data', stackTrace: stack);
      rethrow;
    }
  }

  String get id => itemId;
  bool get isBelowReorder => reorderLevel != null && quantity < reorderLevel!;
}
