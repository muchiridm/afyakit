import 'package:dio/dio.dart';

import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import 'inventory_item.dart';

/// Canonical Inventory Items API service.
///
/// Dio must be the authenticated AfyaKit client so the active
/// tenant, application identity and authentication are included.
class InventoryItemsService {
  final Dio dio;
  final AfyaKitRoutes routes;

  const InventoryItemsService({required this.dio, required this.routes});

  Uri get _base => routes.items();

  Map<String, dynamic> _map(dynamic value) =>
      Map<String, dynamic>.from(value as Map);

  // ─────────────────────────────────────────────
  // Item Types
  // ─────────────────────────────────────────────

  Future<List<InventoryItemType>> listTypes({
    bool includeInactive = false,
  }) async {
    final response = await dio.getUri(routes.itemTypes());

    final data = _map(response.data);

    final types = (data['types'] as List? ?? const [])
        .map((value) => InventoryItemType.fromJson(_map(value)))
        .toList(growable: false);

    return includeInactive
        ? types
        : types.where((type) => type.isActive).toList();
  }

  Future<InventoryItemType> createType({
    required String typeId,
    required String label,
    List<InventoryAttribute> attributes = const [],
  }) async {
    final response = await dio.postUri(
      routes.itemTypes(),
      data: {
        'type_id': typeId.trim(),
        'label': label.trim(),
        'attributes': attributes
            .map((attribute) => attribute.toJson())
            .toList(),
      },
    );

    final data = _map(response.data);

    return InventoryItemType.fromJson(_map(data['type']));
  }

  Future<InventoryItemType> renameType(String typeId, String label) async {
    final response = await dio.patchUri(
      routes.itemTypeById(typeId.trim()),
      data: {'label': label.trim()},
    );

    final data = _map(response.data);

    return InventoryItemType.fromJson(_map(data['type']));
  }

  /// PATCH /items/types/:typeId replaces definitions, preserving existing keys.
  /// The backend accepts only newly appended optional attributes.
  Future<InventoryItemType> addTypeAttribute(
    InventoryItemType type,
    InventoryAttribute attribute,
  ) async {
    final response = await dio.patchUri(
      routes.itemTypeById(type.typeId),
      data: {
        'attributes': [
          ...type.attributes.map((a) => a.toJson()),
          attribute.toJson(),
        ],
      },
    );
    return InventoryItemType.fromJson(_map(_map(response.data)['type']));
  }

  Future<void> archiveType(String typeId) async {
    await dio.deleteUri(routes.itemTypeById(typeId.trim()));
  }

  // ─────────────────────────────────────────────
  // Inventory Items
  // ─────────────────────────────────────────────

  Future<InventoryPage> list({
    String? typeId,
    int page = 1,
    int perPage = 50,
    bool includeArchived = false,
  }) async {
    final normalizedType = typeId?.trim();

    final uri = _base.replace(
      queryParameters: {
        if (normalizedType != null && normalizedType.isNotEmpty)
          'item_type': normalizedType,
        'page': '$page',
        'per_page': '$perPage',
        'include_archived': '$includeArchived',
      },
    );

    final response = await dio.getUri(uri);
    final data = _map(response.data);

    final items = (data['items'] as List? ?? const [])
        .map((value) => InventoryItem.fromJson(_map(value)))
        .toList(growable: false);

    return InventoryPage(
      items,
      data['has_more'] == true,
      (data['page'] as num?)?.toInt() ?? page,
    );
  }

  Future<InventoryItem> get(String id) async {
    final response = await dio.getUri(routes.itemById(id.trim()));

    final data = _map(response.data);

    return InventoryItem.fromJson(_map(data['item']));
  }

  Future<InventoryItem> create(InventoryItemInput item) async {
    final response = await dio.postUri(_base, data: item.toJson());

    final data = _map(response.data);

    return InventoryItem.fromJson(_map(data['item']));
  }

  Future<InventoryItem> update(String id, Map<String, dynamic> patch) async {
    final response = await dio.patchUri(
      routes.itemById(id.trim()),
      data: patch,
    );

    final data = _map(response.data);

    return InventoryItem.fromJson(_map(data['item']));
  }

  Future<void> archive(String id) async {
    await dio.deleteUri(routes.itemById(id.trim()));
  }

  Future<InventoryItem> restore(String id) async {
    final response = await dio.postUri(
      routes.restoreItem(id.trim()),
    );

    final data = _map(response.data);

    return InventoryItem.fromJson(_map(data['item']));
  }
}
