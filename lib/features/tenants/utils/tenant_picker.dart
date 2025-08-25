//lib/features/tenants/utils/decide_tenant.dart

String decideTenant({String fallback = 'afyakit'}) {
  final uri = Uri.base;

  // 1) Query override
  final q = (uri.queryParameters['tenant'] ?? uri.queryParameters['t'])?.trim();
  if (q != null && q.isNotEmpty) return _sanitize(q);

  // 2) Path: /t/<id> or /tenant/<id> or /tenants/<id>
  final segs = uri.pathSegments.map((s) => s.toLowerCase()).toList();
  int ix(String s) => segs.indexOf(s);
  for (final key in const ['t', 'tenant', 'tenants']) {
    final i = ix(key);
    if (i != -1 && i + 1 < segs.length) return _sanitize(segs[i + 1]);
  }

  // 3) Host heuristics
  var host = uri.host.toLowerCase();

  // Local dev → require query/path or use fallback
  if (host == 'localhost' || host == '127.0.0.1' || host == '::1') {
    return fallback;
  }

  // strip common prefixes (keeps things like app.afyakit.app, www.dawapap.com)
  for (final p in const ['www.', 'app.']) {
    if (host.startsWith(p)) host = host.substring(p.length);
  }

  final parts = host.split('.'); // e.g. [dawapap, com] or [afyakit, web, app]
  if (parts.length >= 3) {
    // treat first label as subdomain (afyakit.web.app -> afyakit)
    return _sanitize(_debrand(parts.first));
  }
  if (parts.length == 2) {
    // dawapap.com / afyakit.app / danabtmc.com -> take SLD
    return _sanitize(_debrand(parts.first));
  }

  // 4) Fallback
  return fallback;
}

String _sanitize(String s) => s
    .toLowerCase()
    .replaceAll(RegExp(r'[^a-z0-9-]'), '')
    .replaceAll(RegExp('^-+|+-\$'), '');

/// Strip marketing/build suffixes so hosts like danabtmc-admin.web.app → "danabtmc"
String _debrand(String s) => s.replaceFirst(
  RegExp(r'-(app|admin|web|site|prod|production|stage|staging|dev|preview)$'),
  '',
);
