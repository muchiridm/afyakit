enum InventoryLocationType { store, source, dispensary }

// ─────────────────────────────────────────────
// 🔁 String → InventoryLocationType
// ─────────────────────────────────────────────
extension InventoryLocationTypeParser on String {
  InventoryLocationType toInventoryType() {
    return switch (toLowerCase()) {
      'store' => InventoryLocationType.store,
      'source' => InventoryLocationType.source,
      'dispensary' => InventoryLocationType.dispensary,
      _ => InventoryLocationType.store, // fallback
    };
  }
}

// ─────────────────────────────────────────────
// 🔤 InventoryLocationType → String
// ─────────────────────────────────────────────
extension InventoryLocationTypeX on InventoryLocationType {
  String get asString => switch (this) {
    InventoryLocationType.store => 'store',
    InventoryLocationType.source => 'source',
    InventoryLocationType.dispensary => 'dispensary',
  };
}
