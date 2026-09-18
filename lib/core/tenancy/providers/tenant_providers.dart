// lib/hq/tenants/providers/tenant_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Single source of truth: MUST be overridden in bootstrap.
///
/// Why:
/// - Prevents accidental fallback to "afyakit"
/// - Avoids domain resolution being triggered from arbitrary provider reads
final tenantIdProvider = Provider<String>((ref) {
  throw StateError(
    'tenantIdProvider was read before being overridden.\n'
    'Fix: override it in bootstrapAndRun() ProviderScope.overrides.',
  );
});
