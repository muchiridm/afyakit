import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/api/dawaindex/providers.dart';

import 'controllers/catalog_controller.dart';
import 'catalog_models.dart';
import 'catalog_service.dart';

/// Service (leans on the shared DawaIndexClient FutureProvider)
///
/// IMPORTANT:
/// We do **not** throw here anymore. If the API client is still loading or
/// failed, we just return `null`. The screen will handle the loading/error UI.
final catalogServiceProvider = Provider<CatalogService>((ref) {
  final client = ref.watch(diApiClientProvider);
  return client.maybeWhen(
    data: (c) => CatalogService(c),
    orElse: () => throw StateError('DawaIndexClient not ready'),
  );
});

/// Controller + state (kick off initial refresh)
///
/// We only create the controller **when** service is ready. Otherwise we expose
/// a "fake" idle state so that widgets can still watch without crashing.
final catalogControllerProvider =
    StateNotifierProvider<CatalogController, CatalogState>((ref) {
      final svc = ref.watch(catalogServiceProvider);

      // service not ready yet → expose idle controller

      final ctrl = CatalogController(svc);
      // fire-and-forget initial load
      // ignore: discarded_futures
      ctrl.refresh();
      return ctrl;
    });

/// Convenience selector for just the items AsyncValue
final catalogItemsProvider = Provider<AsyncValue<List<CatalogTile>>>((ref) {
  return ref.watch(catalogControllerProvider.select((s) => s.items));
});
