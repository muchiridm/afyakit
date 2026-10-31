/// Canonical inventory issue DTOs. Stock changes occur only on the backend.
enum InventoryIssueType { transfer, dispense, dispose }
enum InventoryIssueStatus { pending, approved, rejected, cancelled, issued, received, dispensed, disposed }

class InventoryIssueEntry {
  const InventoryIssueEntry({required this.batchId, required this.itemId, required this.quantity});
  final String batchId, itemId;
  final int quantity;
  factory InventoryIssueEntry.fromJson(Map<String, dynamic> json) => InventoryIssueEntry(
    batchId: json['batch_id'] as String, itemId: json['item_id'] as String,
    quantity: (json['quantity'] as num).toInt(),
  );
  Map<String, dynamic> toJson() => {'batch_id': batchId, 'item_id': itemId, 'quantity': quantity};
}

class InventoryIssue {
  const InventoryIssue({required this.id, required this.type, required this.status, required this.fromLocationId,
    required this.entries, this.toLocationId, this.note, this.createdAt, this.createdByName});
  final String id, fromLocationId;
  final InventoryIssueType type;
  final InventoryIssueStatus status;
  final List<InventoryIssueEntry> entries;
  final String? toLocationId, note, createdByName;
  final DateTime? createdAt;
  int get totalQuantity => entries.fold(0, (sum, entry) => sum + entry.quantity);
  factory InventoryIssue.fromJson(Map<String, dynamic> json) => InventoryIssue(
    id: json['issue_id'] as String,
    type: InventoryIssueType.values.byName(json['issue_type'] as String),
    status: InventoryIssueStatus.values.byName(json['status'] as String),
    fromLocationId: json['from_location_id'] as String,
    toLocationId: json['to_location_id'] as String?,
    note: json['note'] as String?,
    createdByName: json['created_by_name'] as String?,
    createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    entries: (json['entries'] as List? ?? const [])
        .map((e) => InventoryIssueEntry.fromJson(Map<String, dynamic>.from(e as Map))).toList(),
  );
}

class InventoryIssuePage {
  const InventoryIssuePage({required this.issues, required this.page, required this.hasMore});
  final List<InventoryIssue> issues;
  final int page;
  final bool hasMore;
}

class InventoryIssueDraft {
  const InventoryIssueDraft({required this.requestKey, required this.type, required this.fromLocationId,
    required this.entries, this.toLocationId, this.note});
  final String requestKey, fromLocationId;
  final InventoryIssueType type;
  final String? toLocationId, note;
  final List<InventoryIssueEntry> entries;
  Map<String, dynamic> toJson() => {
    'request_key': requestKey, 'issue_type': type.name, 'from_location_id': fromLocationId,
    if (type == InventoryIssueType.transfer) 'to_location_id': toLocationId,
    if (note?.trim().isNotEmpty == true) 'note': note!.trim(),
    'entries': entries.map((e) => e.toJson()).toList(),
  };
  void validate() {
    if (requestKey.trim().isEmpty || fromLocationId.trim().isEmpty || entries.isEmpty || entries.length > 100) {
      throw const FormatException('Provide a request key, source store and 1–100 batches.');
    }
    if (type == InventoryIssueType.transfer &&
        (toLocationId == null || toLocationId!.trim().isEmpty || toLocationId == fromLocationId)) {
      throw const FormatException('Select a different destination store.');
    }
    if (type != InventoryIssueType.transfer && toLocationId != null) {
      throw const FormatException('Only transfers can have a destination.');
    }
    if (entries.any((e) => e.quantity <= 0 || e.batchId.isEmpty || e.itemId.isEmpty) ||
        entries.map((e) => e.batchId).toSet().length != entries.length) {
      throw const FormatException('Each unique batch needs an item and a positive whole-number quantity.');
    }
  }
}
