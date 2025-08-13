enum StockViewMode {
  skuOnly, // Flat list of SKUs (no batch/store grouping)
  groupedPerStore, // SKUs grouped by store (can include batch info)
  groupedPerSku, // SKUs grouped centrally, showing totals across stores/batches
  reorder, // Same as groupedPerSku, but with reorder + proposed columns + full editability
}
