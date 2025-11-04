// lib/hq/tenants/v2/providers/tenant_logo_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/hq/tenants/v2/providers/tenant_providers.dart';

/// Your default Firebase Storage bucket (the one in the console screenshot)
const String _bucket = 'afyakit-api.firebasestorage.app';

/// Build a PUBLIC GCS URL directly, no getDownloadURL, no token, no CORS drama.
final tenantLogoUrlProvider = Provider<String?>((ref) {
  final cfg = ref.watch(tenantProfileProvider);

  // public/<tenantId>/branding/logos/logo-primary.png
  final path = 'public/${cfg.id}/branding/logos/logo-primary.png';

  // Plain GCS public URL
  return 'https://storage.googleapis.com/$_bucket/$path';
});
