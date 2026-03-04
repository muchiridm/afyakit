// lib/core/hq/domains/models/domain_binding.dart

import 'package:flutter/foundation.dart';
import 'package:afyakit/core/hq/tenants/utils/tenant_util.dart';

/// Domain binding returned by GET /tenants/:tenantId/domains
@immutable
class DomainBinding {
  /// e.g. "www.dawapap.com" (doc id)
  final String domain;

  /// owner tenant (server always sends it; useful for debugging)
  final String tenantId;

  /// allowlist toggle (must be true for CORS)
  final bool active;

  /// DNS verified? (must be true for CORS)
  final bool verified;

  /// server field
  final bool isPrimary;

  /// TXT token to show while pending
  final String? dnsToken;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DomainBinding({
    required this.domain,
    required this.tenantId,
    this.active = true,
    this.verified = false,
    this.isPrimary = false,
    this.dnsToken,
    this.createdAt,
    this.updatedAt,
  }) : assert(domain != '');

  /// Back-compat with old code that referenced `.primary`.
  bool get primary => isPrimary;

  /// Useful in UI: show token until verified.
  bool get pendingVerification =>
      !verified && (dnsToken != null && dnsToken!.trim().isNotEmpty);

  /// Useful in UI: why CORS might be blocking.
  bool get corsEligible => active && verified;

  factory DomainBinding.fromMap(Map<String, dynamic> m) {
    final rawDomain = (m['domain'] ?? '').toString().trim();
    final rawTenant = (m['tenantId'] ?? '').toString().trim();

    final token = (m['dnsToken'] as String?)?.trim();
    return DomainBinding(
      domain: rawDomain,
      tenantId: rawTenant,
      // ✅ backend defaults active=true, but be defensive
      active: m['active'] != false,
      verified: m['verified'] == true,
      // accept either key; server sends `isPrimary`
      isPrimary: m['isPrimary'] == true || m['primary'] == true,
      dnsToken: (token == null || token.isEmpty) ? null : token,
      createdAt: TenantUtil.parseTs(m['createdAt']),
      updatedAt: TenantUtil.parseTs(m['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
    'domain': domain,
    'tenantId': tenantId,
    'active': active,
    'verified': verified,
    'isPrimary': isPrimary,
    if (dnsToken != null && dnsToken!.trim().isNotEmpty) 'dnsToken': dnsToken,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  DomainBinding copyWith({
    String? domain,
    String? tenantId,
    bool? active,
    bool? verified,
    bool? isPrimary,
    String? dnsToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DomainBinding(
      domain: domain ?? this.domain,
      tenantId: tenantId ?? this.tenantId,
      active: active ?? this.active,
      verified: verified ?? this.verified,
      isPrimary: isPrimary ?? this.isPrimary,
      dnsToken: dnsToken ?? this.dnsToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DomainBinding &&
          runtimeType == other.runtimeType &&
          domain == other.domain &&
          tenantId == other.tenantId &&
          active == other.active &&
          verified == other.verified &&
          isPrimary == other.isPrimary &&
          dnsToken == other.dnsToken &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode => Object.hash(
    domain,
    tenantId,
    active,
    verified,
    isPrimary,
    dnsToken,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'DomainBinding($domain, tenant=$tenantId, '
      'active=$active, verified=$verified, primary=$isPrimary)';
}
