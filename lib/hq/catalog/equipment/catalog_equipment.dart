import 'package:afyakit/hq/catalog/models/catalog_item.dart';

class CatalogEquipment extends CatalogItem {
  final String? model;
  final String? manufacturer;
  final Map<String, dynamic> specs; // e.g., {"voltage":"220V","warranty":"12m"}

  const CatalogEquipment({
    required super.id,
    required super.name,
    this.model,
    this.manufacturer,
    super.synonyms,
    super.classes, // e.g., ["Diagnostics","Imaging"]
    this.specs = const {},
    required super.updatedAt,
  }) : super(
         type: CatalogItemType.equipment,
         source: CatalogSource.local,
         routes: const [],
         isLocalOnly: true,
       );

  factory CatalogEquipment.fromMap(String id, Map<String, dynamic> m) {
    return CatalogEquipment(
      id: id,
      name: m['name'] ?? '',
      model: m['model'],
      manufacturer: m['manufacturer'],
      synonyms: (m['synonyms'] as List?)?.cast<String>() ?? const [],
      classes: (m['classes'] as List?)?.cast<String>() ?? const [],
      specs: (m['specs'] as Map?)?.cast<String, dynamic>() ?? const {},
      updatedAt: (m['updatedAt'] ?? 0) as int,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'itemType': CatalogItemType.equipment.name,
    'source': CatalogSource.local.name,
    'name': name,
    'model': model,
    'manufacturer': manufacturer,
    'synonyms': synonyms,
    'classes': classes,
    'specs': specs,
    'isLocalOnly': true,
    'updatedAt': updatedAt,
  };
}
