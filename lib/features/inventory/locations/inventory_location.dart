class InventoryLocation {
  const InventoryLocation({
    required this.id,
    required this.name,
    required this.typeId,
    required this.isArchived,
    this.description,
  });

  final String id;
  final String name;
  final String typeId;
  final String? description;
  final bool isArchived;

  bool get isStore => typeId == 'store';

  factory InventoryLocation.fromJson(Map<String, dynamic> json) {
    String requiredString(String key) {
      final value = json[key];
      if (value is! String || value.trim().isEmpty) {
        throw FormatException('Location is missing $key');
      }
      return value;
    }

    return InventoryLocation(
      id: requiredString('location_id'),
      name: requiredString('name'),
      typeId: requiredString('location_type'),
      description: json['description']?.toString(),
      isArchived: json['is_archived'] == true,
    );
  }
}

class InventoryLocationPage {
  const InventoryLocationPage({
    required this.locations,
    required this.page,
    required this.hasMore,
  });

  final List<InventoryLocation> locations;
  final int page;
  final bool hasMore;
}

class InventoryLocationType {
  const InventoryLocationType({required this.id, required this.label, required this.isActive});
  final String id;
  final String label;
  final bool isActive;
  factory InventoryLocationType.fromJson(Map<String, dynamic> json) => InventoryLocationType(
    id: json['type_id'] as String,
    label: json['label'] as String,
    isActive: json['is_active'] == true,
  );
}
