import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/core/tenants/services/tenant_resolver.dart';

const _defaultTenant = 'afyakit';

/// Synchronous best-guess from URL/host.
/// If you later “resolve & override”, override this at app bootstrap.
final tenantIdProvider = Provider<String>(
  (ref) => resolveTenantSlug(defaultSlug: _defaultTenant),
);
