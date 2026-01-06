// lib/hq/tenants/providers/tenant_logo_providers.dart

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Your default Firebase Storage bucket
const String _bucket = 'afyakit-api.firebasestorage.app';

String _gcsUrl(String path) => 'https://storage.googleapis.com/$_bucket/$path';

/// Primary logo used in main chrome (catalog header etc.)
///
/// public/<tenantId>/branding/logos/logo-primary.png
final tenantPrimaryLogoUrlProvider = Provider.autoDispose<String>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  final path = 'public/$tenantId/branding/logos/logo-primary.png';
  return _gcsUrl(path);
});

/// Secondary logo (generic) – e.g. login, splash, or alternate themes.
///
/// public/<tenantId>/branding/logos/logo-secondary.png
final tenantSecondaryLogoUrlProvider = Provider.autoDispose<String>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  final path = 'public/$tenantId/branding/logos/logo-secondary.png';
  return _gcsUrl(path);
});
