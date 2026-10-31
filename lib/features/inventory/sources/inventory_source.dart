class InventorySource {
  const InventorySource({
    required this.id,
    required this.name,
    required this.isArchived,
    this.sourceType,
    this.description,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final String? sourceType;
  final String? description;
  final bool isArchived;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory InventorySource.fromJson(Map<String, dynamic> json) {
    DateTime? date(dynamic value) => value is String ? DateTime.tryParse(value) : null;
    return InventorySource(
      id: json['source_id'] as String,
      name: json['name'] as String,
      sourceType: json['source_type'] as String?,
      description: json['description'] as String?,
      isArchived: json['is_archived'] == true,
      createdAt: date(json['created_at']),
      updatedAt: date(json['updated_at']),
    );
  }
}

class InventorySourceInput {
  const InventorySourceInput({required this.name, this.sourceType, this.description});
  final String name;
  final String? sourceType;
  final String? description;

  Map<String, dynamic> toJson() => {
    'name': name.trim(),
    'source_type': (sourceType?.trim().isEmpty ?? true) ? null : sourceType!.trim(),
    'description': (description?.trim().isEmpty ?? true) ? null : description!.trim(),
  };
}

class InventorySourcePage {
  const InventorySourcePage({required this.sources, required this.hasMore});
  final List<InventorySource> sources;
  final bool hasMore;
}
