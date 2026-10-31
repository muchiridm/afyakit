import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'inventory_location.dart';

/// REST-only service. The authenticated Dio client provides authorization;
/// the backend validates tenant and app membership independently.
class InventoryLocationsService {
  InventoryLocationsService({
    required this.dio,
    required this.routes,
    required this.appId,
  }) : assert(appId != '');

  final Dio dio;
  final AfyaKitRoutes routes;
  final String appId;

  // Reuse the existing tenant-scoped Inventory route, changing only the last
  // path segment. Avoids assuming a second API base or a new route helper.
  Uri get _base {
    final itemsUri = routes.items();
    final segments = itemsUri.pathSegments.where((s) => s.isNotEmpty).toList();
    if (segments.isEmpty || segments.last != 'items') {
      throw StateError('Unexpected Inventory items route: $itemsUri');
    }
    segments[segments.length - 1] = 'locations';
    return itemsUri.replace(pathSegments: segments, query: null);
  }

  Options get _options => Options(headers: {'x-app-id': appId});
  Uri _at(String id) => _base.replace(
    pathSegments: [..._base.pathSegments.where((s) => s.isNotEmpty), id],
  );

  Map<String, dynamic> _object(dynamic data) {
    if (data is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(data);
  }

  InventoryLocation _location(dynamic body) =>
      InventoryLocation.fromJson(_object(_object(body)['location']));

  Uri get _types => _base.replace(
    pathSegments: [..._base.pathSegments.where((s) => s.isNotEmpty), 'types'],
  );
  Uri _typeAt(String id, {bool restore = false}) => _types.replace(
    pathSegments: [
      ..._types.pathSegments.where((s) => s.isNotEmpty),
      id,
      if (restore) 'restore',
    ],
  );

  Future<List<InventoryLocationType>> listTypes() async {
    final body = _object((await dio.getUri(_types, options: _options)).data);
    final raw = body['types'];
    if (raw is! List)
      throw const FormatException('Expected location types list');
    return raw.map((v) => InventoryLocationType.fromJson(_object(v))).toList();
  }

  Future<void> createType({required String id, required String label}) async {
    await dio.postUri(
      _types,
      data: {'type_id': id, 'label': label},
      options: _options,
    );
  }

  Future<void> renameType(String id, String label) async {
    await dio.patchUri(_typeAt(id), data: {'label': label}, options: _options);
  }

  Future<void> deactivateType(String id) async {
    await dio.deleteUri(_typeAt(id), options: _options);
  }

  Future<void> reactivateType(String id) async {
    await dio.postUri(_typeAt(id, restore: true), options: _options);
  }

  Future<InventoryLocationPage> list({
    String? typeId,
    bool includeArchived = false,
    int page = 1,
    int perPage = 100,
  }) async {
    final uri = _base.replace(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        'include_archived': '$includeArchived',
        if (typeId != null && typeId.trim().isNotEmpty)
          'location_type': typeId.trim(),
      },
    );
    final body = _object((await dio.getUri(uri, options: _options)).data);
    final raw = body['locations'];
    if (raw is! List) throw const FormatException('Expected locations list');
    return InventoryLocationPage(
      locations: raw
          .map((entry) => InventoryLocation.fromJson(_object(entry)))
          .toList(growable: false),
      page: (body['page'] as num?)?.toInt() ?? page,
      hasMore: body['has_more'] == true,
    );
  }

  Future<List<InventoryLocation>> listAll({
    String? typeId,
    bool includeArchived = false,
  }) async {
    final result = <InventoryLocation>[];
    var page = 1;
    while (true) {
      final response = await list(
        typeId: typeId,
        includeArchived: includeArchived,
        page: page,
      );
      result.addAll(response.locations);
      if (!response.hasMore) return result;
      page++;
    }
  }

  Future<InventoryLocation> get(String id) async =>
      _location((await dio.getUri(_at(id), options: _options)).data);

  Future<InventoryLocation> create({
    required String typeId,
    required String name,
    String? description,
  }) async {
    final body = {
      'location_type': typeId.trim(),
      'name': name.trim(),
      if (description != null) 'description': description.trim(),
    };
    return _location(
      (await dio.postUri(_base, data: body, options: _options)).data,
    );
  }

  Future<InventoryLocation> update(
    String id, {
    String? name,
    String? description,
  }) async {
    if (name == null && description == null) {
      throw ArgumentError('Supply a name or description');
    }
    return _location(
      (await dio.patchUri(
        _at(id),
        data: {
          if (name != null) 'name': name.trim(),
          if (description != null) 'description': description.trim(),
        },
        options: _options,
      )).data,
    );
  }

  Future<void> archive(String id) async {
    await dio.deleteUri(_at(id), options: _options);
  }

  Future<InventoryLocation> restore(String id) async {
    final uri = _at(id).replace(
      pathSegments: [
        ..._at(id).pathSegments.where((s) => s.isNotEmpty),
        'restore',
      ],
    );
    return _location((await dio.postUri(uri, options: _options)).data);
  }
}
