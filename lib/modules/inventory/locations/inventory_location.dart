import 'package:afyakit/modules/inventory/locations/inventory_location_type_enum.dart';

class InventoryLocation {
  final String id; // e.g. "store_004"
  final String tenantId;
  final String name; // e.g. "Main Pharmacy Store"
  final InventoryLocationType type;
  final String? createdBy;
  final DateTime? createdOn;

  // Computed
  String get normalizedName => name.trim().toLowerCase();

  const InventoryLocation({
    required this.id,
    required this.tenantId,
    required this.name,
    required this.type,
    this.createdBy,
    this.createdOn,
  });

  factory InventoryLocation.fromMap(String id, Map<String, dynamic>? map) {
    if (map == null) {
      throw ArgumentError('Map is null for id=$id');
    }

    final typeRaw = map['type'];
    final createdOnRaw = map['createdOn'];

    return InventoryLocation(
      id: id,
      tenantId: map['tenantId'] ?? 'unknown',
      name: (map['name'] ?? 'Unnamed').toString().trim(),
      type: (typeRaw?.toString() ?? 'store').toInventoryType(),
      createdBy: map['createdBy']?.toString(),
      createdOn: createdOnRaw != null
          ? DateTime.tryParse(createdOnRaw.toString())
          : null,
    );
  }

  Map<String, dynamic> toMap() => {
    'tenantId': tenantId,
    'name': name.trim(),
    'type': type.asString,
    if (createdBy != null) 'createdBy': createdBy,
    if (createdOn != null) 'createdOn': createdOn!.toIso8601String(),
  };

  InventoryLocation copyWith({
    String? id,
    String? tenantId,
    String? name,
    InventoryLocationType? type,
    String? createdBy,
    DateTime? createdOn,
  }) {
    return InventoryLocation(
      id: id ?? this.id,
      tenantId: tenantId ?? this.tenantId,
      name: name ?? this.name,
      type: type ?? this.type,
      createdBy: createdBy ?? this.createdBy,
      createdOn: createdOn ?? this.createdOn,
    );
  }

  @override
  String toString() => '$name (${type.name}) [$id]';

  @override
  bool operator ==(Object other) =>
      identical(this, other) || other is InventoryLocation && id == other.id;

  @override
  int get hashCode => id.hashCode;

  bool get isStore => type == InventoryLocationType.store;
  bool get isSource => type == InventoryLocationType.source;
  bool get isDispensary => type == InventoryLocationType.dispensary;
}
