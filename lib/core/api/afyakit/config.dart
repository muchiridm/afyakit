// lib/core/api/afyakit/config.dart

/// Base API URL for AfyaKit services
const String baseApiUrl = 'https://api.afyakit.app';

/// Default tenant used before login or in dev mode
const String defaultTenantId = 'afyakit';

String apiBaseUrl(String tenantId) {
  final t = tenantId.trim().toLowerCase();
  return '$baseApiUrl/api/$t';
}
