// lib/features/inventory/records/deliveries/services/delivery_session_service.dart

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/auth_session/providers/token_provider.dart';

import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_state.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_review_summary.dart';

final deliverySessionServiceProvider = Provider<DeliverySessionService>((ref) {
  final authTokenProvider = ref.read(tokenProvider);

  return DeliverySessionService(authTokenProvider);
});

class DeliverySessionService {
  DeliverySessionService(this.tokenProvider);

  final TokenProvider tokenProvider;

  static const String _prefsKey = 'delivery_session_state';

  // ─────────────────────────────────────────────
  // HTTP helpers
  // ─────────────────────────────────────────────

  Future<Map<String, String>> _headers(String tenantId) async {
    final token = await tokenProvider.getToken();

    return {
      'Content-Type': 'application/json',
      'Authorization': 'Bearer $token',
      'x-tenant-id': tenantId,
    };
  }

  Never _throwHttp(String operation, http.Response response) {
    throw Exception(
      '$operation failed '
      '[${response.statusCode}]: '
      '${response.body}',
    );
  }

  Map<String, dynamic> _decodeObject(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid API response: expected object');
    }

    return decoded;
  }

  List<dynamic> _decodeList(http.Response response) {
    final decoded = jsonDecode(response.body);

    if (decoded is! List<dynamic>) {
      throw Exception('Invalid API response: expected list');
    }

    return decoded;
  }

  // ─────────────────────────────────────────────
  // Sessions
  // ─────────────────────────────────────────────

  Future<DeliverySessionState?> getOpenSession(String tenantId) async {
    final uri = AfyaKitRoutes(tenantId).openDeliverySession();

    final response = await http.get(uri, headers: await _headers(tenantId));

    if (response.statusCode != 200) {
      _throwHttp('getOpenDeliverySession', response);
    }

    final decoded = jsonDecode(response.body);

    if (decoded == null) {
      return null;
    }

    if (decoded is! Map<String, dynamic>) {
      throw Exception('Invalid open delivery session response');
    }

    return DeliverySessionState.fromJson(decoded);
  }

  Future<DeliverySessionState> ensureSession({
    required String tenantId,
    String? source,
    String? storeId,
  }) async {
    final uri = AfyaKitRoutes(tenantId).ensureDeliverySession();

    final body = <String, dynamic>{
      if ((source ?? '').trim().isNotEmpty) 'source': source!.trim(),
      if ((storeId ?? '').trim().isNotEmpty) 'storeId': storeId!.trim(),
    };

    final response = await http.post(
      uri,
      headers: await _headers(tenantId),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      _throwHttp('ensureDeliverySession', response);
    }

    return DeliverySessionState.fromJson(_decodeObject(response));
  }

  Future<DeliverySessionState> updateSession({
    required String tenantId,
    required String deliveryId,
    String? source,
    String? storeId,
  }) async {
    final cleanId = deliveryId.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('deliveryId is required');
    }

    final uri = AfyaKitRoutes(tenantId).updateDeliverySession(cleanId);

    final body = <String, dynamic>{
      if ((source ?? '').trim().isNotEmpty) 'source': source!.trim(),
      if ((storeId ?? '').trim().isNotEmpty) 'storeId': storeId!.trim(),
    };

    final response = await http.patch(
      uri,
      headers: await _headers(tenantId),
      body: jsonEncode(body),
    );

    if (response.statusCode != 200) {
      _throwHttp('updateDeliverySession', response);
    }

    return DeliverySessionState.fromJson(_decodeObject(response));
  }

  // ─────────────────────────────────────────────
  // Review
  // ─────────────────────────────────────────────

  Future<DeliveryReviewSummary> reviewSession({
    required String tenantId,
    required String deliveryId,
  }) async {
    final cleanId = deliveryId.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('deliveryId is required');
    }

    final uri = AfyaKitRoutes(tenantId).reviewDeliverySession(cleanId);

    final response = await http.get(uri, headers: await _headers(tenantId));

    if (response.statusCode != 200) {
      _throwHttp('reviewDeliverySession', response);
    }

    return DeliveryReviewSummary.fromApi(_decodeObject(response));
  }

  // ─────────────────────────────────────────────
  // Finalize
  // ─────────────────────────────────────────────

  Future<DeliveryRecord> finalizeSession({
    required String tenantId,
    required String deliveryId,
  }) async {
    final cleanId = deliveryId.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('deliveryId is required');
    }

    final uri = AfyaKitRoutes(tenantId).finalizeDeliverySession(cleanId);

    final response = await http.post(uri, headers: await _headers(tenantId));

    if (response.statusCode != 200) {
      _throwHttp('finalizeDeliverySession', response);
    }

    final data = _decodeObject(response);

    final record = data['record'];

    if (record is! Map<String, dynamic>) {
      throw Exception(
        'Invalid finalize response: '
        'missing delivery record',
      );
    }

    return DeliveryRecord.fromMap(cleanId, record);
  }

  // ─────────────────────────────────────────────
  // Final delivery records
  // ─────────────────────────────────────────────

  Future<List<DeliveryRecord>> listDeliveries(String tenantId) async {
    final uri = AfyaKitRoutes(tenantId).deliveries();

    final response = await http.get(uri, headers: await _headers(tenantId));

    if (response.statusCode != 200) {
      _throwHttp('listDeliveries', response);
    }

    return _decodeList(response).whereType<Map<String, dynamic>>().map((data) {
      final id = (data['deliveryId'] ?? data['id'] ?? '').toString().trim();

      if (id.isEmpty) {
        throw Exception('Delivery response missing ID');
      }

      return DeliveryRecord.fromMap(id, data);
    }).toList();
  }

  Future<DeliveryRecord> getDelivery({
    required String tenantId,
    required String deliveryId,
  }) async {
    final cleanId = deliveryId.trim();

    if (cleanId.isEmpty) {
      throw ArgumentError('deliveryId is required');
    }

    final uri = AfyaKitRoutes(tenantId).deliveryById(cleanId);

    final response = await http.get(uri, headers: await _headers(tenantId));

    if (response.statusCode != 200) {
      _throwHttp('getDelivery', response);
    }

    return DeliveryRecord.fromMap(cleanId, _decodeObject(response));
  }

  // ─────────────────────────────────────────────
  // Local UX cache only
  // ─────────────────────────────────────────────

  Future<void> persistLocal(DeliverySessionState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setString(_prefsKey, jsonEncode(state.toJson()));
    } catch (e, st) {
      debugPrint(
        '❌ persistLocal failed: '
        '$e\n$st',
      );
    }
  }

  Future<DeliverySessionState?> restoreLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      final raw = prefs.getString(_prefsKey);

      if (raw == null) {
        return null;
      }

      final decoded = jsonDecode(raw);

      if (decoded is! Map<String, dynamic>) {
        return null;
      }

      return DeliverySessionState.fromJson(decoded);
    } catch (e, st) {
      debugPrint(
        '❌ restoreLocal failed: '
        '$e\n$st',
      );

      return null;
    }
  }

  Future<void> clearLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.remove(_prefsKey);
    } catch (e, st) {
      debugPrint(
        '❌ clearLocal failed: '
        '$e\n$st',
      );
    }
  }
}
