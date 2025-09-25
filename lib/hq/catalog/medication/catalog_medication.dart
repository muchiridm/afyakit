import 'package:afyakit/hq/catalog/models/catalog_item.dart';

class CatalogMedication extends CatalogItem {
  /// RxNorm Concept Unique Identifier (also used as doc id)
  final String rxcui;

  /// Optional ATC mapping (level 5) if available from RxClass
  final String? atcCode; // e.g. "N02BE01"
  final String? atcName; // e.g. "Paracetamol"

  /// Dose forms inferred from RxNorm SCD/SBD names (UI filters)
  final List<String> doseForms;

  const CatalogMedication({
    required super.id,
    required super.name,
    super.synonyms = const [],
    super.classes = const [],
    super.routes = const [],
    this.atcCode,
    this.atcName,
    this.doseForms = const [],
    super.isLocalOnly = false,
    required super.updatedAt,
  }) : rxcui = id,
       super(type: CatalogItemType.medication, source: CatalogSource.rxnorm);

  factory CatalogMedication.fromMap(String id, Map<String, dynamic> m) {
    // tolerant to backend fields: rxcui, atc:{l5:{code,name}}, doseForms
    final atc = (m['atc'] as Map?)?['l5'] as Map?;
    return CatalogMedication(
      id: id,
      name: (m['name'] ?? '') as String,
      synonyms: ((m['synonyms'] as List?) ?? const []).cast<String>(),
      classes: ((m['classes'] as List?) ?? const []).cast<String>(),
      routes: ((m['routes'] as List?) ?? const []).cast<String>(),
      doseForms: ((m['doseForms'] as List?) ?? const []).cast<String>(),
      atcCode:
          (atc?['code'] as String?) ??
          // fallback if older field exists
          ((m['atcCodes'] as List?)?.cast<String>().firstOrNull),
      atcName: atc?['name'] as String?,
      isLocalOnly: (m['isLocalOnly'] ?? false) as bool,
      updatedAt: (m['updatedAt'] ?? m['lastSyncedAt'] ?? 0) as int,
    );
  }

  @override
  Map<String, dynamic> toMap() => {
    'itemType': CatalogItemType.medication.name,
    'source': CatalogSource.rxnorm.name,
    'rxcui': rxcui,
    'drugId': rxcui, // keep for symmetry
    'name': name,
    'synonyms': synonyms,
    'classes': classes,
    'routes': routes,
    'doseForms': doseForms,
    if (atcCode != null || atcName != null)
      'atc': {
        'l5': {
          if (atcCode != null) 'code': atcCode,
          if (atcName != null) 'name': atcName,
        },
      },
    'isLocalOnly': isLocalOnly,
    'updatedAt': updatedAt,
  };
}

// tiny extension to avoid null-safety noise
extension _ListX<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : this[0];
}
