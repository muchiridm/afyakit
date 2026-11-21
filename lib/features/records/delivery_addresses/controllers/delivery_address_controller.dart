// lib/features/delivery_addresses/controllers/delivery_address_controller.dart

import 'package:flutter/foundation.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/delivery_addresses/models/delivery_address.dart';

import 'package:afyakit/features/records/delivery_addresses/models/delivery_address_scope.dart';

import 'package:afyakit/features/records/delivery_addresses/services/delivery_address_service.dart';

@immutable
class DeliveryAddressState {
  const DeliveryAddressState({
    this.items = const [],

    this.isLoading = false,

    this.isSaving = false,

    this.error,
  });

  final List<DeliveryAddress> items;

  final bool isLoading;

  final bool isSaving;

  final String? error;

  List<DeliveryAddress> get activeItems =>
      items.where((e) => !e.isArchived).toList(growable: false);

  List<DeliveryAddress> get archivedItems =>
      items.where((e) => e.isArchived).toList(growable: false);

  DeliveryAddress? get defaultAddress {
    for (final item in activeItems) {
      if (item.isDefault) return item;
    }

    return null;
  }

  bool get hasItems => items.isNotEmpty;

  bool get hasActiveItems => activeItems.isNotEmpty;

  bool get hasArchivedItems => archivedItems.isNotEmpty;

  bool get isBusy => isLoading || isSaving;

  DeliveryAddressState copyWith({
    List<DeliveryAddress>? items,

    bool? isLoading,

    bool? isSaving,

    String? error,

    bool clearError = false,
  }) => DeliveryAddressState(
    items: items ?? this.items,

    isLoading: isLoading ?? this.isLoading,

    isSaving: isSaving ?? this.isSaving,

    error: clearError ? null : (error ?? this.error),
  );
}

class DeliveryAddressController extends StateNotifier<DeliveryAddressState> {
  DeliveryAddressController({
    required Future<DeliveryAddressService> serviceFuture,

    required DeliveryAddressScope scope,
  }) : _serviceFuture = serviceFuture,

       _scope = scope,

       super(const DeliveryAddressState());

  final Future<DeliveryAddressService> _serviceFuture;

  final DeliveryAddressScope _scope;

  String get tenantId => _scope.tenantId;

  String get contactId => _scope.contactId;

  // Empty contactId selects backend-authorised member /me routes.
  // Nonempty contactId selects the staff /contacts/{contactId} routes.
  bool get canMutate => tenantId.trim().isNotEmpty;
  bool get isMemberScope => contactId.trim().isEmpty;

  Future<void> load({bool includeArchived = false}) async {
    if (!canMutate) {
      if (mounted) {
        state = state.copyWith(
          error: 'A tenant is required for delivery addresses.',
        );
      }

      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final service = await _serviceFuture;

      final items = await service.list(
        contactId,

        includeArchived: includeArchived,
      );

      if (!mounted) return;

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (error, stack) {
      debugPrint('DeliveryAddressController.load: $error\n$stack');

      if (mounted) {
        state = state.copyWith(isLoading: false, error: error.toString());
      }
    }
  }

  Future<void> refresh({bool includeArchived = false}) =>
      load(includeArchived: includeArchived);

  Future<DeliveryAddress?> create({
    required String label,

    required String recipientName,

    required String recipientPhone,

    String? line1,

    String? line2,

    String? area,

    String? city,

    String? county,

    String? landmark,

    String? instructions,

    DeliveryPinLocation? pinLocation,

    bool isDefault = false,

    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      if (mounted) {
        state = state.copyWith(
          error: 'A tenant is required for delivery addresses.',
        );
      }

      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final service = await _serviceFuture;

      final created = await service.create(
        contactId,

        DeliveryAddress(
          id: '',

          contactId: contactId,

          appId: '',

          label: label.trim(),

          recipientName: recipientName.trim(),

          recipientPhone: recipientPhone.trim(),

          line1: _clean(line1),

          line2: _clean(line2),

          area: _clean(area),

          city: _clean(city),

          county: _clean(county),

          landmark: _clean(landmark),

          instructions: _clean(instructions),

          pinLocation: pinLocation,

          isDefault: isDefault,
        ),
      );

      if (!mounted) return created;

      await load(includeArchived: includeArchived);

      if (mounted) state = state.copyWith(isSaving: false);

      return created;
    } catch (error, stack) {
      debugPrint('DeliveryAddressController.create: $error\n$stack');

      if (mounted) {
        state = state.copyWith(isSaving: false, error: error.toString());
      }

      return null;
    }
  }

  Future<DeliveryAddress?> updateAddress(
    DeliveryAddress address, {

    bool includeArchived = true,
  }) async {
    if (!canMutate ||
        (!isMemberScope && address.contactId != contactId) ||
        address.id.trim().isEmpty) {
      if (mounted) {
        state = state.copyWith(error: 'Invalid delivery address owner or ID.');
      }

      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await (await _serviceFuture).update(contactId, address);

      if (!mounted) return updated;

      await load(includeArchived: includeArchived);

      if (mounted) state = state.copyWith(isSaving: false);

      return updated;
    } catch (error, stack) {
      debugPrint('DeliveryAddressController.updateAddress: $error\n$stack');

      if (mounted) {
        state = state.copyWith(isSaving: false, error: error.toString());
      }

      return null;
    }
  }

  Future<DeliveryAddress?> submitForm({
    DeliveryAddress? existing,

    required String label,

    required String recipientName,

    required String recipientPhone,

    String? line1,

    String? line2,

    String? area,

    String? city,

    String? county,

    String? landmark,

    String? instructions,

    DeliveryPinLocation? pinLocation,

    bool isDefault = false,

    bool includeArchived = true,
  }) {
    if (existing == null) {
      return create(
        label: label,

        recipientName: recipientName,

        recipientPhone: recipientPhone,

        line1: line1,

        line2: line2,

        area: area,

        city: city,

        county: county,

        landmark: landmark,

        instructions: instructions,

        pinLocation: pinLocation,

        isDefault: isDefault,

        includeArchived: includeArchived,
      );
    }

    return updateAddress(
      existing.copyWith(
        label: label.trim(),

        recipientName: recipientName.trim(),

        recipientPhone: recipientPhone.trim(),

        line1: _clean(line1) ?? '',

        line2: _clean(line2) ?? '',

        area: _clean(area) ?? '',

        city: _clean(city) ?? '',

        county: _clean(county) ?? '',

        landmark: _clean(landmark) ?? '',

        instructions: _clean(instructions) ?? '',

        pinLocation: pinLocation,

        isDefault: isDefault,
      ),

      includeArchived: includeArchived,
    );
  }

  Future<DeliveryAddress?> saveAddress(
    DeliveryAddress address, {

    bool includeArchived = true,
  }) => address.id.trim().isEmpty
      ? create(
          label: address.label,

          recipientName: address.recipientName,

          recipientPhone: address.recipientPhone,

          line1: address.line1,

          line2: address.line2,

          area: address.area,

          city: address.city,

          county: address.county,

          landmark: address.landmark,

          instructions: address.instructions,

          pinLocation: address.pinLocation,

          isDefault: address.isDefault,

          includeArchived: includeArchived,
        )
      : updateAddress(address, includeArchived: includeArchived);

  Future<void> archive(String addressId, {bool includeArchived = true}) async {
    if (!canMutate) {
      if (mounted) {
        state = state.copyWith(
          error: 'A tenant is required for delivery addresses.',
        );
      }

      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await (await _serviceFuture).archive(contactId, addressId);

      if (!mounted) return;

      await load(includeArchived: includeArchived);

      if (mounted) state = state.copyWith(isSaving: false);
    } catch (error, stack) {
      debugPrint('DeliveryAddressController.archive: $error\n$stack');

      if (mounted) {
        state = state.copyWith(isSaving: false, error: error.toString());
      }
    }
  }

  Future<void> unarchive(String addressId, {bool includeArchived = true}) =>
      _changeFlag(
        addressId,

        isArchived: false,

        includeArchived: includeArchived,
      );

  Future<void> setDefault(String addressId, {bool includeArchived = true}) =>
      _changeFlag(addressId, isDefault: true, includeArchived: includeArchived);

  Future<void> clearDefault(String addressId, {bool includeArchived = true}) =>
      _changeFlag(
        addressId,

        isDefault: false,

        includeArchived: includeArchived,
      );

  Future<void> _changeFlag(
    String addressId, {

    bool? isArchived,

    bool? isDefault,

    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      if (mounted) {
        state = state.copyWith(
          error: 'A tenant is required for delivery addresses.',
        );
      }

      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final service = await _serviceFuture;

      final existing =
          findById(addressId) ?? await service.get(contactId, addressId);

      if (isDefault == true && existing.isArchived) {
        throw StateError('Archived addresses cannot be default.');
      }

      await service.patchFlags(
        contactId,

        addressId,

        isArchived: isArchived,

        isDefault: isDefault,
      );

      if (!mounted) return;

      await load(includeArchived: includeArchived);

      if (mounted) state = state.copyWith(isSaving: false);
    } catch (error, stack) {
      debugPrint('DeliveryAddressController._changeFlag: $error\n$stack');

      if (mounted) {
        state = state.copyWith(isSaving: false, error: error.toString());
      }
    }
  }

  Future<void> clearError() async {
    if (mounted) state = state.copyWith(clearError: true);
  }

  DeliveryAddress? findById(String addressId) {
    final id = addressId.trim();

    for (final item in state.items) {
      if (item.id == id) return item;
    }

    return null;
  }

  String? normalizeOptionalField(String value) => _clean(value);

  static String? _clean(String? value) {
    final result = value?.trim() ?? '';

    return result.isEmpty ? null : result;
  }
}
