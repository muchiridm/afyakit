// Global hostname index: identity and ownership only.
import 'package:flutter/foundation.dart';

@immutable
class DomainIndex {
  const DomainIndex({
    required this.domain,
    required this.tenantId,
    required this.appId,
  });

  final String domain;
  final String tenantId;
  final String appId;

  factory DomainIndex.fromDoc(String id, Map<String, dynamic> data) {
    return DomainIndex(
      domain: id.trim().toLowerCase(),
      tenantId: (data['tenantId'] ?? '').toString().trim().toLowerCase(),
      appId: (data['appId'] ?? '').toString().trim().toLowerCase(),
    );
  }

  @override
  String toString() => 'DomainIndex($domain → $tenantId/$appId)';
}
