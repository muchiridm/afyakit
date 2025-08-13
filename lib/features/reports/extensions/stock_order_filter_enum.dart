enum StockOrderFilter {
  none, // Show everything based on the current view
  reorderOnly, // Filter items with reorderLevel > 0
  proposedOnly, // Filter items with proposedOrder > 0
}
