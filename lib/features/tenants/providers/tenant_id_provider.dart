//lib/features/tenants/providers/tenant_id_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/tenants/utils/tenant_picker.dart'; // re-exports decideTenant()
import 'package:afyakit/features/tenants/services/tenant_loader.dart';
import 'package:afyakit/features/tenants/services/tenant_config.dart';
import 'package:afyakit/shared/providers/token_provider.dart';

const _defaultTenant = 'afyakit';

/// Synchronous, rule-based tenant id from URL/host/path.
/// Falls back to `_defaultTenant` for localhost or odd hosts.
final tenantIdProvider = Provider<String>(
  (ref) => decideTenant(fallback: _defaultTenant),
);

/// Fully-loaded TenantConfig, preferring backend (public or authed) then assets.
final tenantConfigFutureProvider = FutureProvider<TenantConfig>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);

  TokenProvider? tokens;
  try {
    tokens = ref.read(tokenProvider); // optional; loader will go public w/ null
  } catch (_) {
    tokens = null;
  }

  return loadTenantConfig(
    tenantId,
    tokenProvider: tokens,
    preferBackend: true,
    assetFallback: _defaultTenant,
  );
});
