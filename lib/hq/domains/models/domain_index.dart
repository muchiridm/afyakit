// lib/hq/domains/models/domain_index.dart

import 'package:flutter/material.dart';
import '../../tenants/utils/tenant_util.dart';

@immutable
class DomainIndex {
  final String domain; // doc id (lowercased fqdn)
  final String tenantSlug; // owner (immutable after create)

  /// allowlist toggle (missing => true)
  final bool active;

  /// DNS verified? (missing => false)
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

  factory DomainIndex.fromDoc(String id, Map<String, dynamic> m) {
    final token = (m['dnsToken'] as String?)?.trim();
    return DomainIndex(
      domain: id.trim().toLowerCase(),
      tenantSlug: (m['tenantSlug'] ?? '').toString().trim(),
      active: m['active'] != false, // ✅ default true
      verified: m['verified'] == true,
      isPrimary: m['isPrimary'] == true,
      dnsToken: (token == null || token.isEmpty) ? null : token,
      createdAt: TenantUtil.parseTs(m['createdAt']),
      updatedAt: TenantUtil.parseTs(m['updatedAt']),
    );
  }

  bool get corsEligible => active && verified;

  Map<String, dynamic> toJson() => <String, dynamic>{
    'tenantSlug': tenantSlug,
    'active': active,
    'verified': verified,
    'isPrimary': isPrimary,
    if (dnsToken != null && dnsToken!.trim().isNotEmpty) 'dnsToken': dnsToken,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
