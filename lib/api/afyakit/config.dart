/// Base API URL (no trailing slash)
const String baseApiUrl = 'https://api.afyakit.app';

/// Default tenant used before login or in dev mode
const String defaultTenantId = 'afyakit';

String apiBaseUrl(String tenantId) => '$baseApiUrl/api/$tenantId';
