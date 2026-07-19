// lib/features/retail/catalog/providers/catalog_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import '../controllers/catalog_controller.dart';
import '../services/catalog_service.dart';
import '../models/catalog_models.dart';

final catalogServiceFutureProvider = FutureProvider<CatalogService>((
  ref,
) async {
  final String tenantId = ref.watch(tenantIdProvider).trim().toLowerCase();
  final api = await ref.watch(afyakitClientFutureProvider.future);

  return CatalogService(api: api, routes: AfyaKitRoutes(tenantId));
});

final catalogControllerProvider =
    StateNotifierProvider.autoDispose<CatalogController, CatalogState>((ref) {
      final serviceAsync = ref.watch(catalogServiceFutureProvider);

      return serviceAsync.when(
        data: (service) => CatalogController(service),
        loading: () => throw StateError(
          'CatalogController requested before CatalogService is ready',
        ),
        error: (error, stackTrace) =>
            throw StateError('Failed to initialize CatalogService: $error'),
      );
    });

final catalogReadyProvider = Provider<AsyncValue<void>>((ref) {
  final serviceAsync = ref.watch(catalogServiceFutureProvider);
  return serviceAsync.whenData((_) {});
});

final catalogItemsProvider = Provider<AsyncValue<List<CatalogTile>>>((ref) {
  return ref.watch(catalogControllerProvider.select((s) => s.items));
});
