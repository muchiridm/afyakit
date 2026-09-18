// lib/core/api/afyakit/routes/routes.dart

import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/shared/uri.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

part 'routes_hq.dart';
part 'routes_auth.dart';
part 'routes_inventory.dart';
part 'routes_misc.dart';
part 'routes_retail.dart';
part 'routes_clinical.dart';
part 'routes_insurance.dart';

class AfyaKitRoutes {
  AfyaKitRoutes(String tenantId) : tenantId = tenantId.trim().toLowerCase();

  /// Tenant used for runtime API routes:
  ///
  /// /api/:tenantId/...
  final String tenantId;

  /// Tenant runtime base.
  ///
  /// Example:
  /// https://api.afyakit.app/api/afya
  String get _tenantBase => apiBaseUrl(tenantId);

  /// Core API base.
  ///
  /// Example:
  /// https://api.afyakit.app/api
  String get _coreBase {
    final uri = Uri.parse(_tenantBase);

    final segments = uri.pathSegments
        .where((segment) => segment.trim().isNotEmpty)
        .toList();

    if (segments.isNotEmpty && segments.last.toLowerCase() == tenantId) {
      return uri
          .replace(pathSegments: segments.take(segments.length - 1).toList())
          .toString();
    }

    return uri.toString();
  }

  /// Tenant runtime URI:
  ///
  /// /api/:tenantId/{path}
  Uri _uri(String path, {Map<String, String>? query}) {
    final cleaned = _cleanPath(path);

    final uri = Uri.parse(joinBaseAndPath(_tenantBase, cleaned));

    debugUri('URI tenant', uri);

    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Core URI:
  ///
  /// /api/{path}
  ///
  /// HQ routes therefore use:
  ///
  /// /api/hq/...
  Uri _uriCore(String path, {Map<String, String>? query}) {
    final cleaned = _cleanPath(path);

    final uri = Uri.parse(joinBaseAndPath(_coreBase, cleaned));

    debugUri('URI core', uri);

    return query == null ? uri : uri.replace(queryParameters: query);
  }

  static String _cleanPath(String path) {
    final value = path.trim();

    if (value.isEmpty) {
      return '';
    }

    return value.startsWith('/') ? value.substring(1) : value;
  }

  String _seg(String value) {
    return Uri.encodeComponent(value.trim());
  }
}
