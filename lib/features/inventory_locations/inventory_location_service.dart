import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:afyakit/features/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';

class InventoryLocationService {
  final ApiRoutes api;
  final TokenProvider tokenProvider;

  InventoryLocationService(this.api, this.tokenProvider);

  /// 🔄 Fetch all inventory locations from the relevant typed collection
  Future<List<InventoryLocation>> getLocations({
    required InventoryLocationType type,
  }) async {
    final token = await tokenProvider.getToken();
    final uri = api.getTypedLocations(type); // /stores, /dispensaries, etc.

    final res = await http.get(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('❌ Failed to fetch ${type.name}s: ${res.body}');
    }

    final data = jsonDecode(res.body) as List;
    return data.map((json) {
      final id = json['id'];
      final cleaned = Map<String, dynamic>.from(json)..remove('id');
      return InventoryLocation.fromMap(id, cleaned);
    }).toList();
  }

  /// ➕ Add location with custom ID (e.g. store_004)
  Future<void> addLocation({
    required String name,
    required InventoryLocationType type,
  }) async {
    final token = await tokenProvider.getToken();
    final uri = api.addTypedLocation(type); // new helper

    final payload = {'name': name.trim(), 'type': type.asString};

    final res = await http.post(
      uri,
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode(payload),
    );

    if (res.statusCode != 200 && res.statusCode != 201) {
      throw Exception('❌ Failed to create ${type.name}: ${res.body}');
    }
  }

  /// 🗑️ Delete location by ID
  Future<void> deleteLocation({
    required InventoryLocationType type,
    required String id,
  }) async {
    final token = await tokenProvider.getToken();
    final uri = api.deleteTypedLocation(type, id);

    final res = await http.delete(
      uri,
      headers: {'Authorization': 'Bearer $token'},
    );

    if (res.statusCode != 200) {
      throw Exception('❌ Failed to delete ${type.name}: ${res.body}');
    }
  }
}
