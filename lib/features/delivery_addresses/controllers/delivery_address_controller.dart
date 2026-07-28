// lib/features/delivery_addresses/controllers/delivery_address_controller.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/delivery_addresses/models/delivery_address.dart';
import 'package:afyakit/features/delivery_addresses/services/delivery_address_repo.dart';

@immutable
class DeliveryAddressState {
  final List<DeliveryAddress> items;
  final bool isLoading;
  final bool isSaving;
  final String? error;

  const DeliveryAddressState({
    this.items = const [],
    this.isLoading = false,
    this.isSaving = false,
    this.error,
  });

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
  }) {
    return DeliveryAddressState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class DeliveryAddressController extends StateNotifier<DeliveryAddressState> {
  DeliveryAddressController({
    required DeliveryAddressRepo repo,
    required String tenantId,
    required String ownerUid,
    String? ownerAccountNumber,
  }) : _repo = repo,
       _tenantId = tenantId,
       _ownerUid = ownerUid,
       _ownerAccountNumber = ownerAccountNumber,
       super(const DeliveryAddressState());

  final DeliveryAddressRepo _repo;
  final String _tenantId;
  final String _ownerUid;
  final String? _ownerAccountNumber;

  String get tenantId => _tenantId;
  String get ownerUid => _ownerUid;
  String? get ownerAccountNumber => _ownerAccountNumber;

  bool get canMutate =>
      _tenantId.trim().isNotEmpty && _ownerUid.trim().isNotEmpty;

  Future<void> load({bool includeArchived = false}) async {
    if (!canMutate) {
      state = state.copyWith(
        isLoading: false,
        error: 'Missing tenantId or ownerUid for delivery addresses.',
      );
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final items = await _repo.listForUser(
        tenantId: _tenantId,
        ownerUid: _ownerUid,
        includeArchived: includeArchived,
      );

      state = state.copyWith(items: items, isLoading: false, clearError: true);
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.load failed '
        'tenant=$_tenantId owner=$_ownerUid error=$e\n$st',
      );

      state = state.copyWith(isLoading: false, error: e.toString());
    }
  }

  Future<void> refresh({bool includeArchived = false}) async {
    await load(includeArchived: includeArchived);
  }

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
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final created = await _repo.create(
        tenantId: _tenantId,
        ownerUid: _ownerUid,
        ownerAccountNumber: _ownerAccountNumber,
        label: _trimRequired(label),
        recipientName: _trimRequired(recipientName),
        recipientPhone: _trimRequired(recipientPhone),
        line1: _emptyToNull(line1),
        line2: _emptyToNull(line2),
        area: _emptyToNull(area),
        city: _emptyToNull(city),
        county: _emptyToNull(county),
        landmark: _emptyToNull(landmark),
        instructions: _emptyToNull(instructions),
        pinLocation: pinLocation,
        isDefault: isDefault,
      );

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
      return created;
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.create failed '
        'tenant=$_tenantId owner=$_ownerUid error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<DeliveryAddress?> updateAddress(
    DeliveryAddress address, {
    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final updated = await _repo.update(address);

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
      return updated;
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.updateAddress failed '
        'tenant=$_tenantId owner=$_ownerUid address=${address.id} error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
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
  }) async {
    final normalizedLabel = _trimRequired(label);
    final normalizedRecipientName = _trimRequired(recipientName);
    final normalizedRecipientPhone = _trimRequired(recipientPhone);

    if (existing == null) {
      return create(
        label: normalizedLabel,
        recipientName: normalizedRecipientName,
        recipientPhone: normalizedRecipientPhone,
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

    final updated = existing.copyWith(
      label: normalizedLabel,
      recipientName: normalizedRecipientName,
      recipientPhone: normalizedRecipientPhone,
      line1: _emptyToNull(line1),
      line2: _emptyToNull(line2),
      area: _emptyToNull(area),
      city: _emptyToNull(city),
      county: _emptyToNull(county),
      landmark: _emptyToNull(landmark),
      instructions: _emptyToNull(instructions),
      pinLocation: pinLocation,
      isDefault: isDefault,
    );

    return updateAddress(updated, includeArchived: includeArchived);
  }

  Future<DeliveryAddress?> saveAddress(
    DeliveryAddress address, {
    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return null;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      final saved = await _repo.save(address);

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
      return saved;
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.saveAddress failed '
        'tenant=$_tenantId owner=$_ownerUid address=${address.id} error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
      return null;
    }
  }

  Future<void> archive(String addressId, {bool includeArchived = true}) async {
    if (!canMutate) {
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _repo.archive(
        tenantId: _tenantId,
        ownerUid: _ownerUid,
        addressId: addressId,
      );

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.archive failed '
        'tenant=$_tenantId owner=$_ownerUid address=$addressId error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> unarchive(
    String addressId, {
    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _repo.unarchive(
        tenantId: _tenantId,
        ownerUid: _ownerUid,
        addressId: addressId,
      );

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.unarchive failed '
        'tenant=$_tenantId owner=$_ownerUid address=$addressId error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> setDefault(
    String addressId, {
    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _repo.setDefault(
        tenantId: _tenantId,
        ownerUid: _ownerUid,
        addressId: addressId,
      );

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.setDefault failed '
        'tenant=$_tenantId owner=$_ownerUid address=$addressId error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> clearDefault(
    String addressId, {
    bool includeArchived = true,
  }) async {
    if (!canMutate) {
      state = state.copyWith(
        error: 'Missing tenant/session context for delivery addresses.',
      );
      return;
    }

    state = state.copyWith(isSaving: true, clearError: true);

    try {
      await _repo.clearDefault(
        tenantId: _tenantId,
        ownerUid: _ownerUid,
        addressId: addressId,
      );

      await load(includeArchived: includeArchived);

      state = state.copyWith(isSaving: false, clearError: true);
    } catch (e, st) {
      debugPrint(
        '❌ DeliveryAddressController.clearDefault failed '
        'tenant=$_tenantId owner=$_ownerUid address=$addressId error=$e\n$st',
      );

      state = state.copyWith(isSaving: false, error: e.toString());
    }
  }

  Future<void> clearError() async {
    state = state.copyWith(clearError: true);
  }

  DeliveryAddress? findById(String addressId) {
    final id = addressId.trim();
    if (id.isEmpty) return null;

    for (final item in state.items) {
      if (item.id == id) return item;
    }
    return null;
  }

  String? normalizeOptionalField(String value) => _emptyToNull(value);

  String _trimRequired(String value) => value.trim();

  String? _emptyToNull(String? value) {
    final v = value?.trim() ?? '';
    return v.isEmpty ? null : v;
  }
}
