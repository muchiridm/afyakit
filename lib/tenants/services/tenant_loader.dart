// lib/hq/tenants/services/tenant_loader.dart
import 'dart:convert';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart' show rootBundle;

import 'package:afyakit/config/tenant_config.dart';
import 'package:afyakit/tenants/services/tenant_service.dart';

typedef LogFn = void Function(String);

/// Unified loader: Firestore → asset fallback → default asset.
/// Emits detailed logs for each step.
Future<TenantConfig> loadTenantConfig(
  String tenantId, {
  FirebaseFirestore? db,
  String defaultTenant = 'afyakit',
  LogFn? log,
}) async {
  log ??= debugPrint;
  final sw = Stopwatch()..start();
  log('🔎 [TenantLoader] start: tenant="$tenantId"');

  // 1) Firestore attempt
  try {
    log('🌩️ [TenantLoader] trying Firestore /tenants/$tenantId …');
    final svc = TenantService(db ?? FirebaseFirestore.instance);
    final cfg = await svc.fetchConfig(tenantId);
    sw.stop();
    log(
      '✅ [TenantLoader] Firestore hit in ${sw.elapsedMilliseconds}ms '
      '(displayName="${cfg.displayName}", color="${cfg.primaryColorHex}")',
    );
    return cfg;
  } on FirebaseException catch (e) {
    log(
      '⚠️ [TenantLoader] Firestore FirebaseException: ${e.code} — ${e.message}',
    );
  } catch (e) {
    log('⚠️ [TenantLoader] Firestore load failed: $e');
  }

  // 2) Asset attempt for requested tenant
  try {
    log(
      '📦 [TenantLoader] falling back to asset: assets/tenants/$tenantId.json …',
    );
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
      '🛟 [TenantLoader] using default asset: assets/tenants/$defaultTenant.json …',
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
