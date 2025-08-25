import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter/foundation.dart' show debugPrint;

import 'package:afyakit/features/tenants/services/tenant_config.dart';
import 'package:afyakit/features/tenants/services/tenant_service.dart';
import 'package:afyakit/features/api/api_client.dart';
import 'package:afyakit/features/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';

typedef LogFn = void Function(String);

Future<TenantConfig> loadTenantConfig(
  String tenantId, {
  TokenProvider? tokenProvider,
  bool preferBackend = true,
  String assetFallback = 'afyakit',
  LogFn? log,
}) async {
  log ??= debugPrint;
  final sw = Stopwatch()..start();
  log('🔎 TenantLoader: "$tenantId"');

  // 1) Backend (public if no token; authenticated if token provider exists)
  if (preferBackend) {
    try {
      final api = await ApiClient.create(
        tenantId: tenantId,
        tokenProvider: tokenProvider,
        withAuth: tokenProvider != null,
      );
      final routes = ApiRoutes(tenantId);
      final svc = TenantService(client: api, routes: routes);

      final t = await svc.getTenant(tenantId);
      final cfg = TenantConfig.fromFirestore(tenantId, {
        'displayName': t.displayName,
        'primaryColor': t.primaryColor,
        'logoPath': t.logoPath,
        'flags': <String, dynamic>{},
      });
      sw.stop();
      log(
        '✅ TenantLoader(API) ${sw.elapsedMilliseconds}ms → ${cfg.displayName}',
      );
      return cfg;
    } catch (e) {
      log('⚠️ TenantLoader(API) failed: $e');
    }
  }

  // 2) Asset: assets/tenants/<id>.json
  try {
    final raw = await rootBundle.loadString('assets/tenants/$tenantId.json');
    final cfg = TenantConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
    sw.stop();
    log(
      '✅ TenantLoader(asset) ${sw.elapsedMilliseconds}ms → ${cfg.displayName}',
    );
    return cfg;
  } catch (_) {}

  // 3) Default asset
  final raw = await rootBundle.loadString('assets/tenants/$assetFallback.json');
  final cfg = TenantConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
  sw.stop();
  log(
    '🛟 TenantLoader(default) ${sw.elapsedMilliseconds}ms → ${cfg.displayName}',
  );
  return cfg;
}
