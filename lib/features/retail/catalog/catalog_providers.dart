// lib/core/catalog/catalog_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart'; // afyakitClientProvider
import 'package:afyakit/core/api/afyakit/routes.dart';

import 'controllers/catalog_controller.dart';
import 'catalog_models.dart';
import 'catalog_service.dart';

final catalogServiceProvider = Provider<CatalogService>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);

  final api = ref
      .watch(afyakitClientProvider)
      .maybeWhen(data: (c) => c, orElse: () => null);

  if (api == null) {
    throw StateError('AfyaKitClient not ready');
  }

  final routes = AfyaKitRoutes(tenantId);

  return CatalogService(api: api, routes: routes);
});

final catalogControllerProvider =
    StateNotifierProvider<CatalogController, CatalogState>((ref) {
      final svc = ref.watch(catalogServiceProvider);

      final ctrl = CatalogController(svc);
      // ignore: discarded_futures
      ctrl.refresh();
      return ctrl;
    });

final catalogItemsProvider = Provider<AsyncValue<List<CatalogTile>>>((ref) {
  return ref.watch(catalogControllerProvider.select((s) => s.items));
});
