// lib/features/delivery_addresses/providers/delivery_address_providers.dart

import 'package:afyakit/features/delivery_addresses/models/delivery_address_scope.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/features/delivery_addresses/controllers/delivery_address_controller.dart';
import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/services/delivery_address_repo.dart';
import 'package:afyakit/features/delivery_addresses/services/delivery_navigation_launcher.dart';

final deliveryAddressFirestoreProvider = Provider<FirebaseFirestore>((ref) {
  return FirebaseFirestore.instance;
});

final deliveryAddressRepoProvider = Provider<DeliveryAddressRepo>((ref) {
  return DeliveryAddressRepo(ref.watch(deliveryAddressFirestoreProvider));
});

final deliveryNavigationLauncherProvider = Provider<DeliveryNavigationLauncher>(
  (ref) => DeliveryNavigationLauncher(),
);

final deliveryAddressTenantIdProvider = Provider<String>((ref) {
  return ref.watch(tenantIdProvider);
});

final deliveryAddressCurrentUserProvider = Provider<AuthUser?>((ref) {
  final tenantId = ref.watch(deliveryAddressTenantIdProvider);
  final session = ref.watch(sessionControllerProvider(tenantId));

  return session.maybeWhen(data: (user) => user, orElse: () => null);
});

final currentUserDeliveryAddressScopeProvider = Provider<DeliveryAddressScope>((
  ref,
) {
  final tenantId = ref.watch(deliveryAddressTenantIdProvider);
  final user = ref.watch(deliveryAddressCurrentUserProvider);

  return DeliveryAddressScope(
    tenantId: tenantId,
    ownerUid: user?.uid ?? '',
    ownerAccountNumber: user?.accountNumber,
    ownerLabel: _userLabel(user),
  );
});

final deliveryAddressControllerProvider = StateNotifierProvider.autoDispose
    .family<
      DeliveryAddressController,
      DeliveryAddressState,
      DeliveryAddressScope
    >((ref, scope) {
      final controller = DeliveryAddressController(
        repo: ref.watch(deliveryAddressRepoProvider),
        tenantId: scope.tenantId,
        ownerUid: scope.ownerUid,
        ownerAccountNumber: scope.ownerAccountNumber,
      );

      if (scope.isUsable) {
        Future.microtask(() => controller.load(includeArchived: false));
      }

      return controller;
    });

final deliveryAddressStateProvider = Provider.autoDispose
    .family<DeliveryAddressState, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressControllerProvider(scope));
    });

final deliveryAddressesProvider = Provider.autoDispose
    .family<List<DeliveryAddress>, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).items;
    });

final activeDeliveryAddressesProvider = Provider.autoDispose
    .family<List<DeliveryAddress>, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).activeItems;
    });

final archivedDeliveryAddressesProvider = Provider.autoDispose
    .family<List<DeliveryAddress>, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).archivedItems;
    });

final defaultDeliveryAddressProvider = Provider.autoDispose
    .family<DeliveryAddress?, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).defaultAddress;
    });

final hasDeliveryAddressesProvider = Provider.autoDispose
    .family<bool, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).hasActiveItems;
    });

final deliveryAddressBusyProvider = Provider.autoDispose
    .family<bool, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).isBusy;
    });

final deliveryAddressErrorProvider = Provider.autoDispose
    .family<String?, DeliveryAddressScope>((ref, scope) {
      return ref.watch(deliveryAddressStateProvider(scope)).error;
    });

final deliveryAddressByIdProvider = Provider.autoDispose
    .family<DeliveryAddress?, DeliveryAddressByIdScope>((ref, input) {
      final id = input.addressId.trim();
      if (id.isEmpty) return null;

      final items = ref.watch(deliveryAddressesProvider(input.scope));

      for (final item in items) {
        if (item.id == id) return item;
      }

      return null;
    });

String? _userLabel(AuthUser? user) {
  if (user == null) return null;

  final displayName = (user.displayName ?? '').trim();
  if (displayName.isNotEmpty) return displayName;

  final email = (user.email ?? '').trim();
  if (email.isNotEmpty) return email;

  final phone = (user.phoneNumber ?? '').trim();
  if (phone.isNotEmpty) return phone;

  final accountNumber = (user.accountNumber ?? '').trim();
  if (accountNumber.isNotEmpty) return accountNumber;

  return null;
}
