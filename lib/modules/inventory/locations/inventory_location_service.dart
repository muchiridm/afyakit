// lib/core/inventory_locations/inventory_location_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location.dart';
import 'package:afyakit/modules/inventory/locations/inventory_location_type_enum.dart';

class InventoryLocationService {
  final AfyaKitRoutes routes;
  final Dio dio;

  // ⬅️ new ctor: routes + dio (no TokenProvider)
  InventoryLocationService(this.routes, this.dio);

  /// 🔄 Fetch all inventory locations from the relevant typed collection
  Future<List<InventoryLocation>> getLocations({
    required InventoryLocationType type,
  }) async {
    final uri = routes.getTypedLocations(type); // /inventory-locations/:type
    final res = await dio.getUri(uri);

    final body = res.data;
    final List raw = switch (body) {
      final List l => l,
      final Map m when m['items'] is List => m['items'] as List,
      final String s => (jsonDecode(s) as List),
      _ => const <dynamic>[],
    };

    return raw.map((e) {
      final Map<String, dynamic> m = e is Map<String, dynamic>
          ? Map<String, dynamic>.from(e)
          : Map<String, dynamic>.from(jsonDecode(jsonEncode(e)));
      final id = m['id']?.toString() ?? '';
      final cleaned = Map<String, dynamic>.from(m)..remove('id');
      return InventoryLocation.fromMap(id, cleaned);
    }).toList();
  }

  /// ➕ Add location with custom ID or server-generated one
  Future<InventoryLocation> addLocation({
    required String name,
    required InventoryLocationType type,
  }) async {
    final uri = routes.addTypedLocation(type);
    final payload = {'name': name.trim(), 'type': type.asString};

    final res = await dio.postUri(
      uri,
      data: payload,
      // optional: if your BE uses tenant header; safe to omit if not needed
      options: Options(headers: {'x-tenant-id': routes.tenantId}),
    );

    if (!_ok(res.statusCode ?? 0, expect: {200, 201})) {
      throw Exception('❌ Failed to create ${type.name}: ${res.data}');
    }

    final body = res.data;
    final map = body is Map
        ? Map<String, dynamic>.from(body)
        : <String, dynamic>{};
    final id = map['id']?.toString() ?? '';
    map.remove('id');
    return InventoryLocation.fromMap(id, map);
  }

  /// 🗑️ Delete location by ID
  Future<void> deleteLocation({
    required InventoryLocationType type,
    required String id,
  }) async {
    final uri = routes.deleteTypedLocation(type, id);
    final res = await dio.deleteUri(
      uri,
      options: Options(headers: {'x-tenant-id': routes.tenantId}),
    );
    if (!_ok(res.statusCode ?? 0)) {
      throw Exception('❌ Failed to delete ${type.name}: ${res.data}');
    }
  }

  bool _ok(int status, {Set<int>? expect}) {
    if (expect != null) return expect.contains(status);
    return status >= 200 && status < 300;
  }
}
