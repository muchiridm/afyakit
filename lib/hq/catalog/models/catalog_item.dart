enum CatalogItemType { medication, consumable, equipment }

// Simpler: rxnorm + local only (no DrugBank back-compat)
enum CatalogSource { rxnorm, local }

abstract class CatalogItem {
  final String id; // rxcui for meds; or local ids for others
  final CatalogItemType type;
  final CatalogSource source;

  final String name; // display name
  final List<String> synonyms; // for search
  final List<String> classes; // general tags
  final List<String> routes; // meds primarily

  final bool isLocalOnly;
  final int updatedAt; // epoch ms

  const CatalogItem({
    required this.id,
    required this.type,
    required this.source,
    required this.name,
    this.synonyms = const [],
    this.classes = const [],
    this.routes = const [],
    this.isLocalOnly = false,
    required this.updatedAt,
  });

  Map<String, dynamic> toMap();

  List<String> get searchTerms => {
    name,
    ...synonyms,
    ...classes,
    ...routes,
  }.where((s) => s.isNotEmpty).toList();
}
