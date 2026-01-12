import 'package:afyakit/features/retail/quotes/models/di_sales_tile.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

typedef JsonMap = Map<String, dynamic>;

final diSalesServiceProvider = FutureProvider<DiSalesService>((ref) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientProvider.future);
  return DiSalesService(api: api, routes: routes);
});

class DiSalesService {
  DiSalesService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<Paged<DiSalesTile>> search({
    String? q,
    String? form,
    int limit = 50,
    int offset = 0,
  }) async {
    final uri = routes.diSalesTiles(
      q: q,
      form: form,
      limit: limit,
      offset: offset,
    );

    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    return Paged.fromJson<DiSalesTile>(data, (m) => DiSalesTile.fromJson(m));
  }

  JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
