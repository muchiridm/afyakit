// lib/features/records/issues/providers/grouped_cart_provider.dart
import 'dart:collection';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/records/issues/controllers/controllers/multi_cart_controller.dart';
import 'package:afyakit/features/records/issues/models/view_models/cart_item_models.dart';
import 'package:afyakit/features/records/issues/providers/issue_engine_providers.dart';
import 'package:afyakit/features/records/issues/services/cart_service.dart';

/// Groups cart contents by store and expands them into display models.
/// Recomputes when either:
///  - cartsByStore changes, or
///  - any of the watched inventory streams used inside CartService change.
final groupedCartProvider =
    Provider.autoDispose<Map<String, List<CartDisplayItem>>>((ref) {
      // Only react to the part we need from MultiCartState
      final cartsByStore = ref.watch(
        multiCartProvider.select((s) => s.cartsByStore),
      );

      final engine = ref.read(cartEngineProvider);
      final service = CartService(
        ref,
      ); // CartService must accept `Ref` and use `watch`

      if (cartsByStore.isEmpty) {
        return const <String, List<CartDisplayItem>>{};
      }

      // Stable ordering by storeId so UI lists don't jitter
      final out = SplayTreeMap<String, List<CartDisplayItem>>();

      for (final entry in cartsByStore.entries) {
        // Defensive copy for engine/service functions that might mutate
        final copied = entry.value.batchQuantities.map(
          (itemId, batches) => MapEntry(itemId, Map<String, int>.from(batches)),
        );

        if (engine.isEmpty(copied)) continue;

        final items = service.getDisplayItems(copied);
        if (items.isNotEmpty) out[entry.key] = items;
      }

      return UnmodifiableMapView(out);
    });
