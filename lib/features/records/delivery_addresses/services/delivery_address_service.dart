// lib/features/delivery_addresses/services/delivery_address_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/features/records/delivery_addresses/models/delivery_address.dart';

/// Native Contact staff addresses and authenticated member-owned addresses.
/// An empty contactId selects the backend-owned /me endpoint.
/// Members never send their UID or Contact ID as an ownership claim.
class DeliveryAddressService {
  const DeliveryAddressService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  bool _member(String contactId) => contactId.trim().isEmpty;

  static Map<String, dynamic> _object(Object? source) {
    if (source is Map) return Map<String, dynamic>.from(source);
    throw const FormatException('Expected a JSON object');
  }

  Future<List<DeliveryAddress>> list(
    String contactId, {
    bool includeArchived = false,
  }) async {
    final uri = _member(contactId)
        ? routes.recordsMyDeliveryAddressesList(
            includeArchived: includeArchived,
          )
        : routes.recordsDeliveryAddressesList(
            contactId,
            includeArchived: includeArchived,
          );
    final response = await api.getUri<Object?>(uri);
    final value = _object(response.data)['addresses'];
    if (value is! List) throw const FormatException('Missing addresses array');
    return value.map((item) => DeliveryAddress.fromMap(_object(item))).toList();
  }

  Future<DeliveryAddress> get(String contactId, String addressId) async {
    final uri = _member(contactId)
        ? routes.recordsMyDeliveryAddressGet(addressId)
        : routes.recordsDeliveryAddressGet(contactId, addressId);
    final response = await api.getUri<Object?>(uri);
    return DeliveryAddress.fromMap(_object(_object(response.data)['address']));
  }

  Future<DeliveryAddress> create(
    String contactId,
    DeliveryAddress draft,
  ) async {
    final uri = _member(contactId)
        ? routes.recordsMyDeliveryAddressCreate()
        : routes.recordsDeliveryAddressCreate(contactId);
    final response = await api.postUri<Object?>(uri, data: draft.toWriteMap());
    return DeliveryAddress.fromMap(_object(_object(response.data)['address']));
  }

  Future<DeliveryAddress> update(
    String contactId,
    DeliveryAddress address,
  ) async {
    final uri = _member(contactId)
        ? routes.recordsMyDeliveryAddressUpdate(address.id)
        : routes.recordsDeliveryAddressUpdate(contactId, address.id);
    final response = await api.patchUri<Object?>(
      uri,
      data: address.toWriteMap(),
    );
    return DeliveryAddress.fromMap(_object(_object(response.data)['address']));
  }

  Future<DeliveryAddress> patchFlags(
    String contactId,
    String addressId, {
    bool? isArchived,
    bool? isDefault,
  }) async {
    if (isArchived == null && isDefault == null) {
      throw ArgumentError('At least one flag must be supplied');
    }
    final uri = _member(contactId)
        ? routes.recordsMyDeliveryAddressUpdate(addressId)
        : routes.recordsDeliveryAddressUpdate(contactId, addressId);
    final response = await api.patchUri<Object?>(
      uri,
      data: {
        if (isArchived != null) 'is_archived': isArchived,
        if (isDefault != null) 'is_default': isDefault,
      },
    );
    return DeliveryAddress.fromMap(_object(_object(response.data)['address']));
  }

  Future<void> archive(String contactId, String addressId) async {
    final uri = _member(contactId)
        ? routes.recordsMyDeliveryAddressArchive(addressId)
        : routes.recordsDeliveryAddressArchive(contactId, addressId);
    await api.deleteUri<Object?>(uri);
  }
}
