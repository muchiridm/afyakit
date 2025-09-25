import 'package:afyakit/hq/catalog/models/catalog_item.dart';

class CatalogConsumable extends CatalogItem {
  // Optional structured attributes you might care about
  final Map<String, dynamic>
  specs; // e.g., {"size": "Medium", "material": "Latex-free"}

  const CatalogConsumable({
    required super.id,
    required super.name,
    super.synonyms,
    super.classes, // use as category tags: ["PPE","Dressing"]
    this.specs = const {},
    required super.updatedAt,
  }) : super(
         type: CatalogItemType.consumable,
         source: CatalogSource.local,
         routes: const [],
         isLocalOnly: true,
       );

  factory CatalogConsumable.fromMap(String id, Map<String, dynamic> m) {
    return CatalogConsumable(
      id: id,
      name: m['name'] ?? '',
      synonyms: (m['synonyms'] as List?)?.cast<String>() ?? const [],
      classes: (m['classes'] as List?)?.cast<String>() ?? const [],
      specs: (m['specs'] as Map?)?.cast<String, dynamic>() ?? const {},
      updatedAt: (m['updatedAt'] ?? 0) as int,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'itemType': CatalogItemType.consumable.name,
    'source': CatalogSource.local.name,
    'name': name,
    'synonyms': synonyms,
    'classes': classes,
    'specs': specs,
    'isLocalOnly': true,
    'updatedAt': updatedAt,
  };
}
