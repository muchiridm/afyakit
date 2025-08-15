import 'package:afyakit/users/extensions/combined_user_x.dart';
import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:afyakit/users/providers/combined_user_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/inventory_locations/inventory_location.dart';
import 'package:afyakit/shared/providers/api_route_provider.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_service.dart';
import 'package:afyakit/features/inventory_locations/inventory_location_validator.dart';

// ─────────────────────────────────────────────
// 🧭 InventoryLocationController Implementation
// ─────────────────────────────────────────────
class InventoryLocationController
    extends StateNotifier<AsyncValue<List<InventoryLocation>>> {
  final Ref ref;
  final InventoryLocationType type;
  final InventoryLocationService service;
  bool _isAlive = true;

  InventoryLocationController({
    required this.ref,
    required this.type,
    required this.service,
  }) : super(const AsyncLoading()) {
    _load();
  }

  @override
  void dispose() {
    _isAlive = false;
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final locations = await service.getLocations(type: type);
      if (!_isAlive) return;
      debugPrint('📍 Loaded ${locations.length} ${type.asString} locations');
      state = AsyncData(locations);
    } catch (e, st) {
      if (_isAlive) state = AsyncError(e, st);
    }
  }

  Future<void> add(String rawName) async {
    final trimmedName = rawName.trim();
    final errors = InventoryLocationValidator.validate(
      name: trimmedName,
      type: type,
    );

    if (errors.isNotEmpty) {
      if (_isAlive) {
        state = AsyncError(Exception(errors.join('\n')), StackTrace.current);
      }
      return;
    }

    try {
      await service.addLocation(name: trimmedName, type: type);
      await _load();
    } catch (e, st) {
      if (_isAlive) state = AsyncError(e, st);
    }
  }

  Future<void> delete(String id) async {
    try {
      await service.deleteLocation(type: type, id: id);
      await _load();
    } catch (e, st) {
      if (_isAlive) state = AsyncError(e, st);
    }
  }
}

// ─────────────────────────────────────────────
// 📦 InventoryLocationProvider (per type)
// ─────────────────────────────────────────────
final inventoryLocationProvider = StateNotifierProvider.family
    .autoDispose<
      InventoryLocationController,
      AsyncValue<List<InventoryLocation>>,
      InventoryLocationType
    >((ref, type) {
      final api = ref.watch(apiRouteProvider);
      final token = ref.watch(tokenProvider);
      final service = InventoryLocationService(api, token);
      return InventoryLocationController(
        ref: ref,
        type: type,
        service: service,
      );
    });

// ─────────────────────────────────────────────
// 📦 All Stores Provider (unfiltered)
// ─────────────────────────────────────────────
final allStoresProvider = Provider<List<InventoryLocation>>((ref) {
  final v = ref.watch(inventoryLocationProvider(InventoryLocationType.store));
  return v.asData?.value ?? const <InventoryLocation>[];
});

// ─────────────────────────────────────────────
// 📦 All Dispensaries Provider (unfiltered
// ─────────────────────────────────────────────

final allDispensariesProvider = Provider<List<InventoryLocation>>((ref) {
  final v = ref.watch(
    inventoryLocationProvider(InventoryLocationType.dispensary),
  );
  return v.asData?.value ?? const <InventoryLocation>[];
});

// ─────────────────────────────────────────────
// 🔐 Filtered Store List for Current User
// ─────────────────────────────────────────────
final filteredStoreProvider = FutureProvider<List<InventoryLocation>>((
  ref,
) async {
  final userAsync = ref.watch(combinedUserProvider);
  final storeState = ref.watch(
    inventoryLocationProvider(InventoryLocationType.store),
  );

  if (userAsync is! AsyncData || storeState is! AsyncData) return [];

  final user = userAsync.value;
  final allStores = storeState.value ?? [];

  return user == null
      ? []
      : allStores.where((store) => user.canAccessStore(store.id)).toList();
});
