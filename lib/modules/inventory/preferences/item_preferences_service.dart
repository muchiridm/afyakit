// lib/core/item_preferences/item_preferences_service.dart

import 'dart:convert';
import 'package:dio/dio.dart';

import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/modules/inventory/preferences/utils/item_preference_field.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';

class ItemPreferenceService {
  final AfyaKitRoutes routes;
  final Dio dio;

  ItemPreferenceService({required this.routes, required this.dio});

  // 📥 FETCH VALUES
  Future<List<String>> fetchValues(
    ItemType type,
    ItemPreferenceField field,
  ) async {
    final uri = routes.preferenceField(type.key, field.key);
    final res = await dio.getUri(uri);
    return _asStringList(res.data);
  }

  // ➕ ADD VALUE
  Future<void> addValue(
    ItemType type,
    ItemPreferenceField field,
    String value,
  ) async {
    final uri = routes.preferenceField(type.key, field.key);
    final res = await dio.postUri(uri, data: {'value': value});
    _ensureOk(res.statusCode);
  }

  // ➖ REMOVE VALUE
  Future<void> removeValue(
    ItemType type,
    ItemPreferenceField field,
    String value,
  ) async {
    final uri = routes.preferenceField(type.key, field.key);
    // If your backend prefers query param instead of body for DELETE, do:
    // final uri = routes.preferenceField(type.key, field.key)
    //     .replace(queryParameters: {'value': value});
    final res = await dio.deleteUri(uri, data: {'value': value});
    _ensureOk(res.statusCode);
  }

  // 🔁 SET FULL LIST
  Future<void> setValues(
    ItemType type,
    ItemPreferenceField field,
    List<String> values,
  ) async {
    final uri = routes.preferenceField(type.key, field.key);
    final res = await dio.putUri(uri, data: {'values': values});
    _ensureOk(res.statusCode);
  }

  // ─────────────────────────────────────
  // Helpers
  void _ensureOk(int? sc) {
    final code = sc ?? 0;
    if (code < 200 || code >= 300) {
      throw StateError('Preference API failed with status $code');
    }
  }

  List<String> _asStringList(dynamic body) {
    // Accept: raw List, {items:[...]}, JSON string
    if (body is List) {
      return body.map((e) => e.toString()).toList();
    }
    if (body is Map && body['items'] is List) {
      return (body['items'] as List).map((e) => e.toString()).toList();
    }
    if (body is String && body.isNotEmpty) {
      final parsed = jsonDecode(body);
      if (parsed is List) {
        return parsed.map((e) => e.toString()).toList();
      }
      if (parsed is Map && parsed['items'] is List) {
        return (parsed['items'] as List).map((e) => e.toString()).toList();
      }
    }
    return const <String>[];
  }
}
