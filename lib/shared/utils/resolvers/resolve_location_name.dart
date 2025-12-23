// lib/shared/utils/resolvers/resolve_location_name.dart
import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

String resolveLocationName(
  String? id,
  List<InventoryLocation> stores,
  List<InventoryLocation> dispensaries,
) {
  if (id == null || id.trim().isEmpty) return 'Unknown';

  final lookup = id.trim().toLowerCase();
  final match = [...stores, ...dispensaries].firstWhere(
    (loc) => (loc.id.trim().toLowerCase() == lookup),
    orElse: () => InventoryLocation(
      id: id,
      tenantId: 'unknown',
      name: id, // fallback to showing the raw id
      type: InventoryLocationType.store,
    ),
  );

  return match.name;
}
