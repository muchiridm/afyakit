// lib/core/api/afyakit/routes/routes.dart

import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/shared/uri.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

part 'routes_auth.dart';
part 'routes_users.dart';
part 'routes_inventory.dart';
part 'routes_misc.dart';
part 'routes_retail.dart';
part 'routes_clinical.dart';
part 'routes_health_metrics.dart';
part 'routes_insurance.dart';

part 'routes_domains.dart';
part 'routes_tenants.dart';

class AfyaKitRoutes {
  AfyaKitRoutes(String tenantId) : tenantId = tenantId.trim().toLowerCase();

  /// Tenant tenantId/id used in API base: .../api/:tenantId
  final String tenantId;

  /// Tenant base: https://host/api/:tenantId
  String get _tenantBase => apiBaseUrl(tenantId);

  /// Core base: https://host/api
  ///
  /// Derived by removing the final path segment if it equals [tenantId].
  String get _coreBase {
    final u = Uri.parse(_tenantBase);

    final segs = u.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    if (segs.isNotEmpty && segs.last.toLowerCase() == tenantId) {
      final coreSegs = segs.take(segs.length - 1).toList();

      return u.replace(pathSegments: coreSegs).toString();
    }

    return u.toString();
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final p = _cleanPath(path);
    final uri = Uri.parse(joinBaseAndPath(_tenantBase, p));

    debugUri('URI tenant', uri);

    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Uri _uriCore(String path, {Map<String, String>? query}) {
    final p = _cleanPath(path);
    final uri = Uri.parse(joinBaseAndPath(_coreBase, p));

    debugUri('URI core', uri);

    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  static String _cleanPath(String path) {
    final p = path.trim();

    if (p.isEmpty) return '';

    return p.startsWith('/') ? p.substring(1) : p;
  }

  String _seg(String s) {
    return Uri.encodeComponent(s.trim());
  }
}
