// lib/core/inventory_locations/providers/inventory_location_provider.dart

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_session_guard_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

import 'package:afyakit/core/auth/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/auth/auth_user/extensions/auth_user_x.dart';

import 'package:afyakit/features/inventory/locations/inventory_location.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_service.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_validator.dart';

// ─────────────────────────────────────────────
// 🧭 InventoryLocationController (builds service lazily)
// ─────────────────────────────────────────────
class InventoryLocationController
    extends StateNotifier<AsyncValue<List<InventoryLocation>>> {
  final Ref ref;
  final InventoryLocationType type;
  bool _isAlive = true;

  InventoryLocationController({required this.ref, required this.type})
    : super(const AsyncLoading()) {
    _load();
  }

  @override
  void dispose() {
    _isAlive = false;
    super.dispose();
  }

  // Lazily construct service (await AfyaKit Dio + tenant routes)
  late final Future<InventoryLocationService> _service = _makeService();

  Future<InventoryLocationService> _makeService() async {
    final tenantId = ref.read(tenantIdProvider);
    final client = await ref.read(afyakitClientFutureProvider.future);
    // 👇 Positional ctor: InventoryLocationService(AfyaKitRoutes, Dio)
    return InventoryLocationService(AfyaKitRoutes(tenantId), client.dio);
  }

  /// Ensure token + backend claims are aligned with the current tenant
  Future<void> _ensureTenantReady() async {
    await ref.read(tenantSessionGuardProvider.future);
  }

  Future<void> _load() async {
    try {
      // 🔐 Make sure claimTenant == tenantId before calling API
      await _ensureTenantReady();

      final svc = await _service;
      final locations = await svc.getLocations(type: type);
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
      await _ensureTenantReady();

      final svc = await _service;
      await svc.addLocation(name: trimmedName, type: type);
      await _load();
    } catch (e, st) {
      if (_isAlive) state = AsyncError(e, st);
    }
  }

  Future<void> delete(String id) async {
    try {
      await _ensureTenantReady();

      final svc = await _service;
      await svc.deleteLocation(type: type, id: id);
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
    >((ref, type) => InventoryLocationController(ref: ref, type: type));

// ─────────────────────────────────────────────
// 📦 All Stores Provider (unfiltered)
// ─────────────────────────────────────────────
final allStoresProvider = Provider<List<InventoryLocation>>((ref) {
  final v = ref.watch(inventoryLocationProvider(InventoryLocationType.store));
  return v.asData?.value ?? const <InventoryLocation>[];
});

// ─────────────────────────────────────────────
// 📦 All Dispensaries Provider (unfiltered)
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
  final userAsync = ref.watch(currentUserProvider);
  final storesAsync = ref.watch(
    inventoryLocationProvider(InventoryLocationType.store),
  );

  if (userAsync is! AsyncData || storesAsync is! AsyncData) return [];

  final user = userAsync.value;
  final allStores = storesAsync.value ?? [];

  return user == null
      ? []
      : allStores.where((store) => user.canAccessStore(store.id)).toList();
});
