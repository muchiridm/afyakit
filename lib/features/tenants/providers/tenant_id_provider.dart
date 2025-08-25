// lib/features/tenants/providers/tenant_id_provider.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/tenants/services/tenant_resolver.dart';

const _defaultTenant = 'afyakit';

/// Synchronous best-guess from URL/host. The bootstrap will override this with
/// the authoritative slug (resolved async) and inject the loaded config.
final tenantIdProvider = Provider<String>(
  (ref) => resolveTenantSlug(defaultSlug: _defaultTenant),
);
