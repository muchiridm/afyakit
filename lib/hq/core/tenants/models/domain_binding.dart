import 'package:flutter/foundation.dart';
import 'package:afyakit/hq/core/tenants/utils/tenant_util.dart';

/// Domain binding returned by /tenants/:slug/domains
@immutable
class DomainBinding {
  final String domain; // e.g. acme.health
  final bool verified; // DNS verified?
  final bool isPrimary; // mirrors server field
  final String? dnsToken; // TXT token to show while pending
  final DateTime? createdAt;
  final DateTime? updatedAt;

  const DomainBinding({
    required this.domain,
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
      !verified && (dnsToken != null && dnsToken!.isNotEmpty);

  factory DomainBinding.fromMap(Map<String, dynamic> m) {
    final token = (m['dnsToken'] as String?)?.trim();
    return DomainBinding(
      domain: (m['domain'] ?? '').toString(),
      verified: m['verified'] == true,
      // accept either key; server sends `isPrimary`
      isPrimary: m['isPrimary'] == true || m['primary'] == true,
      dnsToken: (token == null || token.isEmpty) ? null : token,
      createdAt: TenantUtil.parseTs(m['createdAt']),
      updatedAt: TenantUtil.parseTs(m['updatedAt']),
    );
  }

  Map<String, dynamic> toJson() => {
    'domain': domain,
    'verified': verified,
    'isPrimary': isPrimary, // send canonical key to server
    if (dnsToken != null && dnsToken!.isNotEmpty) 'dnsToken': dnsToken,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };

  DomainBinding copyWith({
    String? domain,
    bool? verified,
    bool? isPrimary,
    String? dnsToken,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return DomainBinding(
      domain: domain ?? this.domain,
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
          verified == other.verified &&
          isPrimary == other.isPrimary &&
          dnsToken == other.dnsToken &&
          createdAt == other.createdAt &&
          updatedAt == other.updatedAt;

  @override
  int get hashCode =>
      Object.hash(domain, verified, isPrimary, dnsToken, createdAt, updatedAt);

  @override
  String toString() =>
      'DomainBinding($domain, verified: $verified, isPrimary: $isPrimary)';
}
