// lib/features/delivery_addresses/providers/delivery_address_providers.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/delivery_addresses/controllers/delivery_address_controller.dart';
import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/services/delivery_address_repo.dart';
import 'package:afyakit/features/delivery_addresses/services/delivery_navigation_launcher.dart';

final deliveryAddressFirestoreProvider = Provider<FirebaseFirestore>(
  (ref) => FirebaseFirestore.instance,
);

final deliveryAddressRepoProvider = Provider<DeliveryAddressRepo>((ref) {
  final firestore = ref.watch(deliveryAddressFirestoreProvider);
  return DeliveryAddressRepo(firestore);
});

final deliveryNavigationLauncherProvider = Provider<DeliveryNavigationLauncher>(
  (ref) {
    return DeliveryNavigationLauncher();
  },
);

final deliveryAddressTenantIdProvider = Provider<String>((ref) {
  return ref.watch(tenantIdProvider);
});

final deliveryAddressCurrentUserProvider = Provider<AuthUser?>((ref) {
  final tenantId = ref.watch(deliveryAddressTenantIdProvider);
  final session = ref.watch(sessionControllerProvider(tenantId));
  return session.maybeWhen(data: (user) => user, orElse: () => null);
});

final deliveryAddressControllerProvider =
    StateNotifierProvider.autoDispose<
      DeliveryAddressController,
      DeliveryAddressState
    >((ref) {
      final repo = ref.watch(deliveryAddressRepoProvider);
      final tenantId = ref.watch(deliveryAddressTenantIdProvider);
      final user = ref.watch(deliveryAddressCurrentUserProvider);

      final controller = DeliveryAddressController(
        repo: repo,
        tenantId: tenantId,
        ownerUid: user?.uid ?? '',
        ownerAccountNumber: user?.accountNumber,
      );

      if (user != null) {
        Future.microtask(() => controller.load(includeArchived: false));
      }

      return controller;
    });

final deliveryAddressStateProvider = Provider<DeliveryAddressState>((ref) {
  return ref.watch(deliveryAddressControllerProvider);
});

final deliveryAddressesProvider = Provider<List<DeliveryAddress>>((ref) {
  return ref.watch(deliveryAddressStateProvider).items;
});

final activeDeliveryAddressesProvider = Provider<List<DeliveryAddress>>((ref) {
  return ref.watch(deliveryAddressStateProvider).activeItems;
});

final archivedDeliveryAddressesProvider = Provider<List<DeliveryAddress>>((
  ref,
) {
  return ref.watch(deliveryAddressStateProvider).archivedItems;
});

final defaultDeliveryAddressProvider = Provider<DeliveryAddress?>((ref) {
  return ref.watch(deliveryAddressStateProvider).defaultAddress;
});

final hasDeliveryAddressesProvider = Provider<bool>((ref) {
  return ref.watch(deliveryAddressStateProvider).hasActiveItems;
});

final deliveryAddressBusyProvider = Provider<bool>((ref) {
  return ref.watch(deliveryAddressStateProvider).isBusy;
});

final deliveryAddressErrorProvider = Provider<String?>((ref) {
  return ref.watch(deliveryAddressStateProvider).error;
});

final deliveryAddressByIdProvider = Provider.family<DeliveryAddress?, String>((
  ref,
  addressId,
) {
  final id = addressId.trim();
  if (id.isEmpty) return null;

  final items = ref.watch(deliveryAddressesProvider);
  for (final item in items) {
    if (item.id == id) return item;
  }
  return null;
});
