// lib/core/domains/models/domain_binding.dart

import 'package:flutter/foundation.dart';

import 'package:afyakit/features/hq/tenants/utils/tenant_util.dart';

/// App-owned domain binding returned by:
/// GET /api/hq/tenants/:tenantId/apps/:appId/domains
@immutable
class DomainBinding {
  /// e.g. "www.dawapap.com"
  final String domain;

  /// Shared backend/data universe.
  final String tenantId;

  /// Product/application that owns this domain.
  final String appId;

  /// Allowlist toggle.
  final bool active;

  /// DNS verification state.
  final bool verified;

  /// Primary domain for this app.
  final bool isPrimary;

  /// TXT verification token while pending.
  final String? dnsToken;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DomainBinding({
    required this.domain,
    required this.tenantId,
    required this.appId,
    this.active = true,
    this.verified = false,
    this.isPrimary = false,
    this.dnsToken,
    this.createdAt,
    this.updatedAt,
  }) : assert(domain != '');

  bool get pendingVerification =>
      !verified && (dnsToken != null && dnsToken!.trim().isNotEmpty);

  bool get corsEligible => active && verified;

  factory DomainBinding.fromMap(Map<String, dynamic> map) {
    final token = map['dnsToken']?.toString().trim();

    return DomainBinding(
      domain: (map['domain'] ?? '').toString().trim().toLowerCase(),
      tenantId: (map['tenantId'] ?? '').toString().trim().toLowerCase(),
      appId: (map['appId'] ?? '').toString().trim().toLowerCase(),
      active: map['active'] != false,
      verified: map['verified'] == true,
      isPrimary: map['isPrimary'] == true,
      dnsToken: token == null || token.isEmpty ? null : token,
      createdAt: TenantUtil.parseTs(map['createdAt']),
      updatedAt: TenantUtil.parseTs(map['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'domain': domain,
      'tenantId': tenantId,
      'appId': appId,
      'active': active,
      'verified': verified,
      'isPrimary': isPrimary,
      if (dnsToken != null && dnsToken!.trim().isNotEmpty) 'dnsToken': dnsToken,
      if (createdAt != null) 'createdAt': createdAt,
      if (updatedAt != null) 'updatedAt': updatedAt,
    };
  }

  DomainBinding copyWith({
    String? domain,
    String? tenantId,
    String? appId,
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
      appId: appId ?? this.appId,
      active: active ?? this.active,
      verified: verified ?? this.verified,
      isPrimary: isPrimary ?? this.isPrimary,
      dnsToken: dnsToken ?? this.dnsToken,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is DomainBinding &&
            runtimeType == other.runtimeType &&
            domain == other.domain &&
            tenantId == other.tenantId &&
            appId == other.appId &&
            active == other.active &&
            verified == other.verified &&
            isPrimary == other.isPrimary &&
            dnsToken == other.dnsToken &&
            createdAt == other.createdAt &&
            updatedAt == other.updatedAt;
  }

  @override
  int get hashCode => Object.hash(
    domain,
    tenantId,
    appId,
    active,
    verified,
    isPrimary,
    dnsToken,
    createdAt,
    updatedAt,
  );

  @override
  String toString() =>
      'DomainBinding('
      '$domain, '
      'tenant=$tenantId, '
      'app=$appId, '
      'active=$active, '
      'verified=$verified, '
      'primary=$isPrimary'
      ')';
}
