import 'package:flutter/material.dart';

@immutable
class DeliveryAddressScope {
  const DeliveryAddressScope({
    required this.tenantId,
    required this.ownerUid,
    this.ownerAccountNumber,
    this.ownerLabel,
  });

  final String tenantId;
  final String ownerUid;
  final String? ownerAccountNumber;
  final String? ownerLabel;

  bool get isUsable {
    return tenantId.trim().isNotEmpty && ownerUid.trim().isNotEmpty;
  }

  @override
  bool operator ==(Object other) {
    return other is DeliveryAddressScope &&
        other.tenantId == tenantId &&
        other.ownerUid == ownerUid &&
        other.ownerAccountNumber == ownerAccountNumber &&
        other.ownerLabel == ownerLabel;
  }

  @override
  int get hashCode {
    return Object.hash(tenantId, ownerUid, ownerAccountNumber, ownerLabel);
  }
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
  bool operator ==(Object other) {
    return other is DeliveryAddressByIdScope &&
        other.scope == scope &&
        other.addressId == addressId;
  }

  @override
  int get hashCode => Object.hash(scope, addressId);
}
