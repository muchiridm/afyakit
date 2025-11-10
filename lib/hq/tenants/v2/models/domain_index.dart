// lib/hq/tenants/v2/models/domain_index.dart

import 'package:flutter/material.dart';

import '../utils/tenant_util.dart';

@immutable
class DomainIndex {
  final String domain; // doc id (lowercased fqdn)
  final String tenantSlug; // owner (immutable after create)
  final bool active;
  final bool verified;
  final bool isPrimary;
  final String? dnsToken; // for TXT verification
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DomainIndex({
    required this.domain,
    required this.tenantSlug,
    this.active = true,
    this.verified = false,
    this.isPrimary = false,
    this.dnsToken,
    this.createdAt,
    this.updatedAt,
  });

  factory DomainIndex.fromDoc(String id, Map<String, dynamic> m) => DomainIndex(
    domain: id.trim().toLowerCase(),
    tenantSlug: (m['tenantSlug'] ?? '').toString(),
    active: m['active'] == true,
    verified: m['verified'] == true,
    isPrimary: m['isPrimary'] == true,
    dnsToken: (m['dnsToken'] as String?)?.trim(),
    createdAt: TenantUtil.parseTs(m['createdAt']),
    updatedAt: TenantUtil.parseTs(m['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'tenantSlug': tenantSlug,
    'active': active,
    'verified': verified,
    'isPrimary': isPrimary,
    if (dnsToken != null && dnsToken!.isNotEmpty) 'dnsToken': dnsToken,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
