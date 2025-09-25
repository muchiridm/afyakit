import 'package:afyakit/hq/catalog/consumable/catalog_consumable.dart';
import 'package:afyakit/hq/catalog/equipment/catalog_equipment.dart';
import 'package:afyakit/hq/catalog/models/catalog_item.dart';
import 'package:afyakit/hq/catalog/medication/catalog_medication.dart';

class CatalogFactory {
  static CatalogItem fromMap(String id, Map<String, dynamic> m) {
    final t = (m['itemType'] ?? 'medication') as String;
    switch (t) {
      case 'medication':
        return CatalogMedication.fromMap(id, m);
      case 'consumable':
        return CatalogConsumable.fromMap(id, m);
      case 'equipment':
        return CatalogEquipment.fromMap(id, m);
      default:
        throw ArgumentError('Unknown catalog itemType: $t for $id');
    }
  }
}
