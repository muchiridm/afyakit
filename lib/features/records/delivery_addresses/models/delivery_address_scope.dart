import 'package:flutter/foundation.dart';

/// Address owner scope. The backend always validates actual ownership.
/// Empty contactId selects authenticated /me endpoints;
/// nonempty contactId selects staff /contacts/{contactId} endpoints.
@immutable
class DeliveryAddressScope {
  const DeliveryAddressScope({
    required this.tenantId,
    required this.contactId,
    this.ownerLabel,
  });

  final String tenantId;
  final String contactId;
  final String? ownerLabel;

  /// Staff-owned workflow: requires a verified native Contact ID.
  bool get isUsable =>
      tenantId.trim().isNotEmpty && contactId.trim().isNotEmpty;

  /// Member workflow: requires tenant context, never a client owner ID.
  bool get isMemberScope =>
      tenantId.trim().isNotEmpty && contactId.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is DeliveryAddressScope &&
      other.tenantId == tenantId &&
      other.contactId == contactId;

  @override
  int get hashCode => Object.hash(tenantId, contactId);
}

@immutable
class DeliveryAddressByIdScope {
  const DeliveryAddressByIdScope({
    required this.scope,
    required this.addressId,
  });

  final DeliveryAddressScope scope;
  final String addressId;

  @override
  bool operator ==(Object other) =>
      other is DeliveryAddressByIdScope &&
      other.scope == scope &&
      other.addressId == addressId;

  @override
  int get hashCode => Object.hash(scope, addressId);
}
