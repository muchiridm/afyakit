// lib/features/retail/catalog/catalog_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'catalog_controller.dart';
import 'catalog_models.dart';
import 'catalog_service.dart';

final catalogServiceProvider = Provider<CatalogService?>((ref) {
  final tenantIdRaw = ref.watch(tenantSlugProvider);
  final tenantId = tenantIdRaw.trim().toLowerCase();

  final apiAsync = ref.watch(afyakitClientFutureProvider);

  return apiAsync.when(
    data: (api) {
      final routes = AfyaKitRoutes(tenantId);
      return CatalogService(api: api, routes: routes);
    },
    loading: () => null,
    error: (_, __) => null,
  );
});

final catalogControllerProvider =
    StateNotifierProvider.autoDispose<CatalogController, CatalogState>((ref) {
      final link = ref.keepAlive();

      final service = ref.watch(catalogServiceProvider);
      final controller = CatalogController(service);

      ref.listen<CatalogService?>(catalogServiceProvider, (prev, next) {
        if (prev == null && next != null) {
          controller.setService(next);
        }
      });

      ref.onDispose(() {
        Future.delayed(const Duration(minutes: 5), link.close);
      });

      return controller;
    });

final catalogItemsProvider = Provider<AsyncValue<List<CatalogTile>>>((ref) {
  return ref.watch(catalogControllerProvider.select((s) => s.items));
});
