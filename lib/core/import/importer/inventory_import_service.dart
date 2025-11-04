// lib/core/import/importer/inventory_import_service.dart

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kDebugMode, kIsWeb, debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:dio/dio.dart' as dio;
import 'package:http/http.dart' as http;

import 'package:afyakit/api/afyakit/routes.dart';
import 'package:afyakit/api/afyakit/providers.dart'; // ⬅️ NEW (afyakitClientProvider)
import 'package:afyakit/hq/tenants/v2/providers/tenant_slug_provider.dart'; // ⬅️ NEW (tenantId)
import 'package:afyakit/core/import/importer/models/import_type_x.dart';
import 'package:afyakit/core/import/importer/models/inventory_import_result.dart';
import 'package:afyakit/core/auth_users/providers/auth_session/token_provider.dart';

/// Service provider
final inventoryImportServiceProvider = Provider<InventoryImportService>((ref) {
  return InventoryImportService(ref);
});

class InventoryImportService {
  final Ref _ref;
  InventoryImportService(this._ref);

  // ────────────────────────────────────────────────────────────────────────────
  // PUBLIC API

  Future<InventoryImportResult> validate({
    required ImportType type,
    required String filename,
    required Uint8List bytes,
  }) {
    _log('🔎 validate()', {
      'type': type.name,
      'filename': filename,
      'bytes': bytes.length,
    });
    return _upload(
      type: type,
      filename: filename,
      bytes: bytes,
      dryRun: true,
      persist: false,
      groupMap: null,
    );
  }

  /// Persist with an optional fileGroup → canonical group mapping.
  Future<InventoryImportResult> persist({
    required ImportType type,
    required String filename,
    required Uint8List bytes,
    Map<String, String>? groupMap,
  }) {
    _log('💾 persist()', {
      'type': type.name,
      'filename': filename,
      'bytes': bytes.length,
      'groupMap.keys': groupMap?.keys.length ?? 0,
    });
    return _upload(
      type: type,
      filename: filename,
      bytes: bytes,
      dryRun: false,
      persist: true,
      groupMap: groupMap,
    );
  }

  Future<Uint8List> downloadTemplate({required ImportType type}) async {
    // Resolve tenant + client + routes
    final tenantId = _ref.read(tenantSlugProvider);
    final client = await _ref.read(afyakitClientProvider.future);
    final routes = AfyaKitRoutes(tenantId);

    final uri = routes.importTemplate(type.name);
    _log('⬇️ downloadTemplate()', {'uri': uri.toString()});

    final resp = await client.dio.getUri<List<int>>(
      uri,
      options: dio.Options(responseType: dio.ResponseType.bytes),
    );

    final data = resp.data ?? const <int>[];
    _log('⬇️ template-bytes', {'len': data.length});
    return Uint8List.fromList(data);
  }

  // ────────────────────────────────────────────────────────────────────────────
  // INTERNAL

  Future<InventoryImportResult> _upload({
    required ImportType type,
    required String filename,
    required Uint8List bytes,
    required bool dryRun,
    required bool persist,
    Map<String, String>? groupMap,
  }) async {
    if (bytes.isEmpty) {
      _log('❌ _upload: empty file', {});
      return InventoryImportResult.error('Selected file is empty.');
    }

    _log('🚀 _upload start', {
      'type': type.name,
      'filename': filename,
      'bytes': bytes.length,
      'dryRun': dryRun,
      'persist': persist,
      'groupMap.keys': groupMap?.keys.length ?? 0,
    });

    // Resolve tenant + client + routes
    final tenantId = _ref.read(tenantSlugProvider);
    final client = await _ref.read(afyakitClientProvider.future);
    final routes = AfyaKitRoutes(tenantId);

    // ── Web: send raw bytes (manual Authorization header)
    if (kIsWeb) {
      final uri = routes.importInventoryRaw(
        type: type.name,
        dryRun: dryRun,
        persist: persist,
      );
      _log('🌐 WEB upload URI', {'uri': uri.toString()});

      String? token;
      try {
        token = await _ref.read(tokenProvider).tryGetToken();
        _log('🔑 token', {'len': token?.length ?? 0});
      } catch (e) {
        _log('⚠️ tokenProvider error', {'err': e.toString()});
        token = null;
      }

      final headers = <String, String>{
        'Content-Type': 'application/octet-stream',
        if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
        'X-Filename': filename,
        if (groupMap != null) 'X-Group-Map': jsonEncode(groupMap),
      };

      final resp = await http.post(uri, headers: headers, body: bytes);

      _log('🌐 web response', {
        'status': resp.statusCode,
        'len': resp.body.length,
      });

      try {
        final json = jsonDecode(resp.body) as Map<String, dynamic>;
        return InventoryImportResult.fromJson(json);
      } catch (_) {
        return InventoryImportResult.error(
          'HTTP ${resp.statusCode}: ${resp.body}',
        );
      }
    }

    // ── Native: multipart (Dio handles Authorization via AfyaKitClient)
    final uri = routes.importInventory(
      type: type.name,
      dryRun: dryRun,
      persist: persist,
    );
    _log('📱 NATIVE upload URI', {'uri': uri.toString()});

    final form = dio.FormData.fromMap({
      'file': dio.MultipartFile.fromBytes(bytes, filename: filename),
    });

    try {
      final resp = await client.dio.postUri(
        uri,
        data: form,
        options: dio.Options(
          responseType: dio.ResponseType.json,
          headers: {if (groupMap != null) 'X-Group-Map': jsonEncode(groupMap)},
        ),
        onSendProgress: (sent, total) =>
            _log('📦 progress', {'sent': sent, 'total': total}),
      );

      _log('✅ native response', {
        'status': resp.statusCode,
        'hasData': resp.data != null,
      });

      return InventoryImportResult.fromJson(resp.data as Map<String, dynamic>);
    } on dio.DioException catch (e) {
      _log('❌ DioException', {
        'message': e.message,
        'status': e.response?.statusCode,
        'url': e.requestOptions.uri.toString(),
      });

      final data = e.response?.data;
      if (data is Map<String, dynamic>) {
        return InventoryImportResult.fromJson({
          'ok': false,
          'message': data['message']?.toString(),
          'errors': (data['errors'] as List?)
              ?.map((x) => x.toString())
              .toList(),
        });
      }
      return InventoryImportResult.error(e.message ?? 'Network error');
    } catch (e) {
      _log('❌ Unexpected exception', {'err': e.toString()});
      return InventoryImportResult.error(e.toString());
    }
  }

  // ────────────────────────────────────────────────────────────────────────────

  void _log(String tag, Map<String, Object?> data) {
    if (!kDebugMode) return;
    debugPrint('$tag → ${jsonEncode(data)}');
  }
}
