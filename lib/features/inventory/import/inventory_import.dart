/// Response returned by the canonical Inventory import endpoint.
class InventoryImportResult {
  const InventoryImportResult({
    required this.ok,
    required this.dryRun,
    required this.itemType,
    required this.rows,
    required this.created,
    required this.updated,
    required this.errors,
  });

  final bool ok;
  final bool dryRun;
  final String itemType;
  final int rows;
  final int created;
  final int updated;
  final List<String> errors;

  factory InventoryImportResult.fromJson(Map<String, dynamic> json) =>
      InventoryImportResult(
        ok: json['ok'] == true,
        dryRun: json['dry_run'] == true,
        itemType: (json['item_type'] ?? '').toString(),
        rows: (json['rows'] as num?)?.toInt() ?? 0,
        created: (json['created'] as num?)?.toInt() ?? 0,
        updated: (json['updated'] as num?)?.toInt() ?? 0,
        errors: (json['errors'] as List? ?? const [])
            .map((error) => error.toString())
            .toList(growable: false),
      );
}
