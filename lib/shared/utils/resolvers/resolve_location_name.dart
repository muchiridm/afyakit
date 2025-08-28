// lib/shared/utils/resolvers/resolve_location_name.dart

import 'package:afyakit/core/inventory_locations/inventory_location.dart';
import 'package:afyakit/core/inventory_locations/inventory_location_type_enum.dart';

String resolveLocationName(
  String? id,
  List<InventoryLocation> stores,
  List<InventoryLocation> dispensaries,
) {
  if (id == null) return 'Unknown';

  final match = [...stores, ...dispensaries].firstWhere(
    (loc) => loc.id.trim().toLowerCase() == id.trim().toLowerCase(),
    orElse: () => InventoryLocation(
      id: id,
      tenantId: 'unknown',
      name: id,
      type: InventoryLocationType.store,
    ),
  );

  return match.name;
}
