/// Controls which stock items are shown in the report.
enum StockAvailabilityFilter {
  /// Show all items, regardless of stock status.
  all,

  /// Show only items currently in stock.
  inStock,

  /// Show only items that are out of stock.
  outOfStock,
}

/// Extension methods for `StockVisibilityFilter`.
extension StockAvailabilityFilterX on StockAvailabilityFilter {
  /// Display label for UI purposes.
  String get label => switch (this) {
    StockAvailabilityFilter.all => 'All Items',
    StockAvailabilityFilter.inStock => 'In-stock Only',
    StockAvailabilityFilter.outOfStock => 'Out of Stock Only',
  };
}
