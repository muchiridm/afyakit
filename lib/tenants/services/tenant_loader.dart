// lib/hq/tenants/services/tenant_loader.dart
import 'dart:convert';
import 'package:afyakit/tenants/services/tenant_service.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'package:afyakit/config/tenant_config.dart';
import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/shared/api/api_routes.dart';
import 'package:afyakit/shared/providers/token_provider.dart';

typedef LogFn = void Function(String);

/// Unified loader: Backend (HTTP) → asset fallback → default asset.
/// Emits detailed logs for each step.
///
/// Pass a TokenProvider if the /tenants/:slug endpoint requires auth.
/// If you already have an ApiClient/ApiRoutes, you can supply them to reuse.
Future<TenantConfig> loadTenantConfig(
  String tenantId, {
  ApiClient? client,
  ApiRoutes? routes,
  TokenProvider? tokenProvider,
  bool withAuth = true,
  String defaultTenant = 'afyakit',
  LogFn? log,
}) async {
  log ??= debugPrint;
  final sw = Stopwatch()..start();
  log('🔎 [TenantLoader] start: tenant="$tenantId"');

  // 1) Backend attempt (preferred)
  try {
    final apiClient =
        client ??
        await ApiClient.create(
          tenantId: tenantId,
          tokenProvider: tokenProvider,
          withAuth: withAuth,
        );
    final apiRoutes = routes ?? ApiRoutes(tenantId);
    final svc = TenantService(client: apiClient, routes: apiRoutes);

    log('🌐 [TenantLoader] hitting GET /tenants/$tenantId …');
    final t = await svc.getTenant(tenantId); // TenantSummary

    // Build a TenantConfig from the API shape (defensive defaults).
    final cfg = TenantConfig.fromJson(<String, dynamic>{
      'slug': t.slug,
      'displayName': t.displayName,
      'primaryColor': t.primaryColor,
      if (t.logoPath != null) 'logoPath': t.logoPath,
      // Flags are optional; server may add them later.
      // Keep an empty map to satisfy older constructors.
      'flags': <String, dynamic>{},
      // You can pass owner/email/status if your TenantConfig supports them.
      'ownerUid': t.ownerUid,
      'ownerEmail': t.ownerEmail,
      'status': t.status,
    });

    sw.stop();
    log(
      '✅ [TenantLoader] API hit in ${sw.elapsedMilliseconds}ms '
      '(displayName="${cfg.displayName}", color="${cfg.primaryColorHex}")',
    );
    return cfg;
  } catch (e) {
    log('⚠️ [TenantLoader] API load failed: $e');
  }

  // 2) Asset attempt for requested tenant
  try {
    log('📦 [TenantLoader] falling back: assets/tenants/$tenantId.json …');
    final raw = await rootBundle.loadString('assets/tenants/$tenantId.json');
    final cfg = TenantConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
    sw.stop();
    log(
      '✅ [TenantLoader] asset hit in ${sw.elapsedMilliseconds}ms '
      '(displayName="${cfg.displayName}", color="${cfg.primaryColorHex}")',
    );
    return cfg;
  } catch (e) {
    log('⚠️ [TenantLoader] asset "$tenantId.json" not found/invalid: $e');
  }

  // 3) Final default asset fallback
  try {
    log(
      '🛟 [TenantLoader] default asset: assets/tenants/$defaultTenant.json …',
    );
    final raw = await rootBundle.loadString(
      'assets/tenants/$defaultTenant.json',
    );
    final cfg = TenantConfig.fromJson(json.decode(raw) as Map<String, dynamic>);
    sw.stop();
    log(
      '✅ [TenantLoader] default asset "$defaultTenant" loaded in '
      '${sw.elapsedMilliseconds}ms',
    );
    return cfg;
  } catch (e) {
    sw.stop();
    final msg =
        '❌ [TenantLoader] final fallback failed (tenant="$tenantId", default="$defaultTenant"). Error: $e';
    log(msg);
    throw StateError(msg);
  }
}
