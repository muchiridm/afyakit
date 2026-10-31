import 'package:dio/dio.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'inventory_delivery.dart';

/// All stock postings belong to the backend. This service never writes Firestore.
class InventoryDeliveriesService {
  const InventoryDeliveriesService({required this.dio, required this.routes, required this.appId});
  final Dio dio;
  final AfyaKitRoutes routes;
  final String appId;
  Options get _options => Options(headers: {'x-app-id': appId});
  Uri get _base => routes.deliveries();
  Uri _at(String id, [String? suffix]) => _base.replace(pathSegments: [
    ..._base.pathSegments.where((s) => s.isNotEmpty),
    if (suffix != null) 'session', id, if (suffix != null) suffix,
  ]);
  Uri get _open => _base.replace(pathSegments: [..._base.pathSegments.where((s) => s.isNotEmpty), 'session', 'open']);
  Uri get _session => _base.replace(pathSegments: [..._base.pathSegments.where((s) => s.isNotEmpty), 'session']);
  Uri _sessionAt(String id) => _base.replace(pathSegments: [..._base.pathSegments.where((s) => s.isNotEmpty), 'session', id]);
  Map<String, dynamic> _json(dynamic data) {
    if (data is! Map) throw const FormatException('Expected JSON object');
    return Map<String, dynamic>.from(data);
  }
  Future<InventoryDeliveryPage> list({int page = 1, int perPage = 50}) async {
    final response = await dio.getUri(_base.replace(queryParameters: {'page': '$page', 'per_page': '$perPage'}), options: _options);
    final json = _json(response.data);
    return InventoryDeliveryPage(deliveries: (json['deliveries'] as List? ?? const [])
      .map((e) => InventoryDelivery.fromJson(_json(e))).toList(), hasMore: json['has_more'] == true);
  }
  Future<List<InventoryDelivery>> listAll() async {
    final result = <InventoryDelivery>[];
    for (var page = 1; ; page++) {
      final part = await list(page: page);
      result.addAll(part.deliveries);
      if (!part.hasMore) return result;
    }
  }
  Future<InventoryDelivery> get(String id) async =>
      InventoryDelivery.fromJson(_json((await dio.getUri(_at(id), options: _options)).data));
  Future<InventoryDeliverySession?> openSession() async {
    final data = (await dio.getUri(_open, options: _options)).data;
    return data == null ? null : InventoryDeliverySession.fromJson(_json(data));
  }
  Future<InventoryDeliverySession> ensureSession({String? source, String? storeId}) async =>
    InventoryDeliverySession.fromJson(_json((await dio.postUri(_session,
      data: {if (source?.trim().isNotEmpty == true) 'source': source!.trim(),
        if (storeId?.trim().isNotEmpty == true) 'store_id': storeId!.trim()},
      options: _options)).data));
  Future<InventoryDeliverySession> updateSession(String id, {String? source, String? storeId}) async =>
    InventoryDeliverySession.fromJson(_json((await dio.patchUri(_sessionAt(id),
      data: {if (source?.trim().isNotEmpty == true) 'source': source!.trim(),
        if (storeId?.trim().isNotEmpty == true) 'store_id': storeId!.trim()},
      options: _options)).data));
  Future<InventoryDeliveryReview> review(String id) async =>
    InventoryDeliveryReview.fromJson(_json((await dio.getUri(_sessionAt(id), options: _options)).data));
  /// Backend finalization is idempotent for a delivery ID.
  Future<InventoryDelivery> finalize(String id) async {
    final json = _json((await dio.postUri(_at(id, 'finalize'), options: _options)).data);
    return InventoryDelivery.fromJson(_json(json['record']));
  }
}
