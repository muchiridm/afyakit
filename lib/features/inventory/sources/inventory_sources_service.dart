import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'inventory_source.dart';

class InventorySourcesService {
  const InventorySourcesService({required this.dio, required this.routes});
  final Dio dio;
  final AfyaKitRoutes routes;

  Future<InventorySourcePage> list({
    int page = 1,
    int perPage = 100,
    bool includeArchived = false,
  }) async {
    final uri = routes.sources().replace(
      queryParameters: {
        'page': '$page',
        'per_page': '$perPage',
        'include_archived': '$includeArchived',
      },
    );

    final response = await dio.getUri(uri);
    final data = Map<String, dynamic>.from(response.data as Map);
    return InventorySourcePage(
      sources: (data['sources'] as List)
          .map(
            (value) => InventorySource.fromJson(
              Map<String, dynamic>.from(value as Map),
            ),
          )
          .toList(),
      hasMore: data['has_more'] == true,
    );
  }

  Future<List<InventorySource>> listAll({bool includeArchived = false}) async {
    final sources = <InventorySource>[];
    for (var page = 1; ; page++) {
      final result = await list(page: page, includeArchived: includeArchived);
      sources.addAll(result.sources);
      if (!result.hasMore) break;
    }
    return sources;
  }

  Future<InventorySource> create(InventorySourceInput input) async {
    final response = await dio.postUri(routes.sources(), data: input.toJson());
    return _readSource(response.data);
  }

  Future<InventorySource> update(String id, InventorySourceInput input) async {
    final response = await dio.patchUri(
      routes.sourceById(id),
      data: input.toJson(),
    );
    return _readSource(response.data);
  }

  Future<void> archive(String id) async {
    await dio.deleteUri(routes.sourceById(id));
  }

  Future<InventorySource> restore(String id) async {
    final response = await dio.postUri(routes.restoreSource(id));
    return _readSource(response.data);
  }

  InventorySource _readSource(dynamic responseData) {
    final data = Map<String, dynamic>.from(responseData as Map);
    return InventorySource.fromJson(
      Map<String, dynamic>.from(data['source'] as Map),
    );
  }
}
