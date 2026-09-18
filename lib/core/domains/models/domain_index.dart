// lib/core/domains/models/domain_index.dart

import 'package:flutter/foundation.dart';

@immutable
class DomainIndex {
  /// Hostname/doc ID.
  final String domain;

  /// Shared backend/data universe.
  final String tenantId;

  /// Product/application to launch.
  final String appId;

  /// Domain enabled for runtime use.
  final bool active;

  /// Domain has completed verification.
  final bool verified;

  const DomainIndex({
    required this.domain,
    required this.tenantId,
    required this.appId,
    this.active = true,
    this.verified = false,
  });

  factory DomainIndex.fromDoc(String id, Map<String, dynamic> map) {
    return DomainIndex(
      domain: id.trim().toLowerCase(),
      tenantId: (map['tenantId'] ?? '').toString().trim().toLowerCase(),
      appId: (map['appId'] ?? '').toString().trim().toLowerCase(),
      active: map['active'] != false,
      verified: map['verified'] == true,
    );
  }

  bool get launchEligible => active && verified;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'tenantId': tenantId,
      'appId': appId,
      'active': active,
      'verified': verified,
    };
  }

  @override
  String toString() =>
      'DomainIndex('
      '$domain → '
      'tenant=$tenantId, '
      'app=$appId, '
      'active=$active, '
      'verified=$verified'
      ')';
}
