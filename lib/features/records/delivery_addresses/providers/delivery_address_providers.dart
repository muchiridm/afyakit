// lib/features/delivery_addresses/providers/delivery_address_providers.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/auth/auth_session/controllers/session_controller.dart';
import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:afyakit/features/records/delivery_addresses/controllers/delivery_address_controller.dart';
import 'package:afyakit/features/records/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/records/delivery_addresses/models/delivery_address_scope.dart';
import 'package:afyakit/features/records/delivery_addresses/services/delivery_address_service.dart';
import 'package:afyakit/features/records/delivery_addresses/services/delivery_navigation_launcher.dart';

final deliveryAddressServiceProvider = FutureProvider<DeliveryAddressService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider).trim().toLowerCase();
  final api = await ref.watch(afyakitClientFutureProvider.future);
  return DeliveryAddressService(api: api, routes: AfyaKitRoutes(tenantId));
});

final deliveryNavigationLauncherProvider = Provider<DeliveryNavigationLauncher>(
  (ref) => DeliveryNavigationLauncher(),
);

final deliveryAddressTenantIdProvider = Provider<String>(
  (ref) => ref.watch(tenantIdProvider).trim().toLowerCase(),
);

final deliveryAddressCurrentUserProvider = Provider<AuthUser?>((ref) {
  final tenantId = ref.watch(deliveryAddressTenantIdProvider);
  final session = ref.watch(sessionControllerProvider(tenantId));
  return session.maybeWhen(data: (user) => user, orElse: () => null);
});

/// Member scope deliberately carries no Contact ID: /me resolves ownership on BE.
/// Staff screens continue to supply an explicit, verified native Contact ID.
final currentUserDeliveryAddressScopeProvider = Provider<DeliveryAddressScope>((
  ref,
) {
  final tenantId = ref.watch(deliveryAddressTenantIdProvider);
  final user = ref.watch(deliveryAddressCurrentUserProvider);
  return DeliveryAddressScope(
    tenantId: tenantId,
    contactId: '',
    ownerLabel: _userLabel(user),
  );
});

final deliveryAddressControllerProvider = StateNotifierProvider.autoDispose
    .family<
      DeliveryAddressController,
      DeliveryAddressState,
      DeliveryAddressScope
    >((ref, scope) {
      final serviceFuture = ref.watch(deliveryAddressServiceProvider.future);
      final controller = DeliveryAddressController(
        serviceFuture: serviceFuture,
        scope: scope,
      );
      if (scope.tenantId.trim().isNotEmpty) {
        Future.microtask(() {
          if (controller.mounted) controller.load();
        });
      }
      return controller;
    });

final deliveryAddressStateProvider = Provider.autoDispose
    .family<DeliveryAddressState, DeliveryAddressScope>(
      (ref, scope) => ref.watch(deliveryAddressControllerProvider(scope)),
    );
final deliveryAddressesProvider = Provider.autoDispose
    .family<List<DeliveryAddress>, DeliveryAddressScope>(
      (ref, scope) => ref.watch(deliveryAddressStateProvider(scope)).items,
    );
final activeDeliveryAddressesProvider = Provider.autoDispose
    .family<List<DeliveryAddress>, DeliveryAddressScope>(
      (ref, scope) =>
          ref.watch(deliveryAddressStateProvider(scope)).activeItems,
    );
final archivedDeliveryAddressesProvider = Provider.autoDispose
    .family<List<DeliveryAddress>, DeliveryAddressScope>(
      (ref, scope) =>
          ref.watch(deliveryAddressStateProvider(scope)).archivedItems,
    );
final defaultDeliveryAddressProvider = Provider.autoDispose
    .family<DeliveryAddress?, DeliveryAddressScope>(
      (ref, scope) =>
          ref.watch(deliveryAddressStateProvider(scope)).defaultAddress,
    );
final hasDeliveryAddressesProvider = Provider.autoDispose
    .family<bool, DeliveryAddressScope>(
      (ref, scope) =>
          ref.watch(deliveryAddressStateProvider(scope)).hasActiveItems,
    );
final deliveryAddressBusyProvider = Provider.autoDispose
    .family<bool, DeliveryAddressScope>(
      (ref, scope) => ref.watch(deliveryAddressStateProvider(scope)).isBusy,
    );
final deliveryAddressErrorProvider = Provider.autoDispose
    .family<String?, DeliveryAddressScope>(
      (ref, scope) => ref.watch(deliveryAddressStateProvider(scope)).error,
    );
final deliveryAddressByIdProvider = Provider.autoDispose
    .family<DeliveryAddress?, DeliveryAddressByIdScope>((ref, input) {
      final id = input.addressId.trim();
      if (id.isEmpty) return null;
      for (final item in ref.watch(deliveryAddressesProvider(input.scope))) {
        if (item.id == id) return item;
      }
      return null;
    });

String? _userLabel(AuthUser? user) {
  if (user == null) return null;
  final name = (user.displayName ?? '').trim();
  if (name.isNotEmpty) return name;
  final email = (user.activeAppEmailLower ?? '').trim();
  if (email.isNotEmpty) return email;
  final phone = (user.phoneNumber ?? '').trim();
  if (phone.isNotEmpty) return phone;
  final account = (user.accountNumber ?? '').trim();
  return account.isNotEmpty ? account : null;
}
