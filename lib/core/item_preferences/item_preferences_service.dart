import 'dart:convert';
import 'package:http/http.dart' as http;

import 'package:afyakit/api/api_routes.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';
import 'package:afyakit/core/item_preferences/utils/item_preference_field.dart';
import 'package:afyakit/core/inventory/models/item_type_enum.dart';

class ItemPreferenceService {
  final ApiRoutes apiRoutes;
  final TokenProvider tokenProvider;

  ItemPreferenceService(this.apiRoutes, this.tokenProvider);

  // 📥 FETCH VALUES
  Future<List<String>> fetchValues(
    ItemType type,
    ItemPreferenceField field,
  ) async {
    final res = await _request(
      method: 'GET',
      url: apiRoutes.preferenceField(type.key, field.key),
    );

    return List<String>.from(jsonDecode(res.body));
  }

  // ➕ ADD VALUE
  Future<void> addValue(
    ItemType type,
    ItemPreferenceField field,
    String value,
  ) async {
    await _request(
      method: 'POST',
      url: apiRoutes.preferenceField(type.key, field.key),
      body: {'value': value},
    );
  }

  // ➖ REMOVE VALUE
  Future<void> removeValue(
    ItemType type,
    ItemPreferenceField field,
    String value,
  ) async {
    await _request(
      method: 'DELETE',
      url: apiRoutes.preferenceField(type.key, field.key),
      body: {'value': value},
    );
  }

  // 🔁 SET FULL LIST
  Future<void> setValues(
    ItemType type,
    ItemPreferenceField field,
    List<String> values,
  ) async {
    await _request(
      method: 'PUT',
      url: apiRoutes.preferenceField(type.key, field.key),
      body: {'values': values},
    );
  }

  // ─────────────────────────────────────
  // 🔐 INTERNAL REQUEST WRAPPER
  Future<http.Response> _request({
    required String method,
    required Uri url,
    Map<String, dynamic>? body,
  }) async {
    final token = await tokenProvider.getToken();

    final headers = {
      'Authorization': 'Bearer $token',
      'Content-Type': 'application/json',
    };

    final encodedBody = body != null ? jsonEncode(body) : null;
    late http.Response res;

    try {
      switch (method) {
        case 'GET':
          res = await http.get(url, headers: headers);
          break;
        case 'POST':
          res = await http.post(url, headers: headers, body: encodedBody);
          break;
        case 'PUT':
          res = await http.put(url, headers: headers, body: encodedBody);
          break;
        case 'DELETE':
          res = await http.delete(url, headers: headers, body: encodedBody);
          break;
        default:
          throw Exception('Unsupported method: $method');
      }
    } catch (e) {
      throw Exception('Network error while performing $method: $e');
    }

    if (res.statusCode < 200 || res.statusCode >= 300) {
      throw Exception("❌ [$method] ${url.path} failed:\n${res.body}");
    }

    return res;
  }
}
