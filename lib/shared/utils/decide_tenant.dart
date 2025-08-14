// Build-time define; leave default empty so we don't mask other sources
const kDefaultTenant = String.fromEnvironment('TENANT', defaultValue: '');

String decideTenant() {
  final uri = Uri.base;

  // 1) URL override (?tenant=...)
  final fromQuery = uri.queryParameters['tenant']?.trim().toLowerCase();
  if (fromQuery != null && fromQuery.isNotEmpty) return fromQuery;

  // 2) Build-time define (works on ALL platforms including web)
  if (kDefaultTenant.isNotEmpty) return kDefaultTenant.toLowerCase();

  // 3) Domain-based routing (web)
  final host = uri.host.toLowerCase();
  if (host.contains('dawapap')) return 'dawapap';
  if (host.contains('danabtmc')) return 'danabtmc';
  if (host.contains('afyakit')) return 'afyakit';

  // 4) Safe fallback
  return 'afyakit';
}
