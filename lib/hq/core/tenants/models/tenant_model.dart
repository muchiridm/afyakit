// lib/hq/tenants/models/tenant.dart
import 'package:afyakit/hq/core/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/hq/core/tenants/utils/tenant_util.dart';

/// Canonical Tenant model (matches backend TenantDTO).
class Tenant {
  /// Backend uses the slug as the document id.
  final String slug;

  final String displayName;
  final String primaryColor;
  final String? logoPath;
  final Map<String, dynamic> flags;

  final TenantStatus status;
  final String? ownerUid;
  final String? ownerEmail;

  /// Mirrors /tenants/{slug}.primaryDomain
  final String? primaryDomain;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  const Tenant({
    required this.slug,
    required this.displayName,
    required this.primaryColor,
    this.logoPath,
    this.flags = const {},
    this.status = TenantStatus.active,
    this.ownerUid,
    this.ownerEmail,
    this.primaryDomain,
    this.createdAt,
    this.updatedAt,
  });

  /// For compatibility with old code that expected `id`.
  String get id => slug;

  Tenant copyWith({
    String? slug,
    String? displayName,
    String? primaryColor,
    String? logoPath,
    Map<String, dynamic>? flags,
    TenantStatus? status,
    String? ownerUid,
    String? ownerEmail,
    String? primaryDomain,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Tenant(
      slug: slug ?? this.slug,
      displayName: displayName ?? this.displayName,
      primaryColor: primaryColor ?? this.primaryColor,
      logoPath: logoPath ?? this.logoPath,
      flags: flags ?? this.flags,
      status: status ?? this.status,
      ownerUid: ownerUid ?? this.ownerUid,
      ownerEmail: ownerEmail ?? this.ownerEmail,
      primaryDomain: primaryDomain ?? this.primaryDomain,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory Tenant.fromJson(Map<String, dynamic> j) => Tenant(
    slug: (j['slug'] ?? '').toString(),
    displayName: (j['displayName'] ?? '').toString(),
    primaryColor: (j['primaryColor'] ?? '#1565C0').toString(),
    logoPath: (j['logoPath'] as String?)?.trim().isEmpty == true
        ? null
        : (j['logoPath'] as String?),
    flags: Map<String, dynamic>.from(j['flags'] as Map? ?? const {}),
    status: TenantStatusX.parse(j['status'] as String?),
    ownerUid: (j['ownerUid'] as String?)?.trim().isEmpty == true
        ? null
        : (j['ownerUid'] as String?),
    ownerEmail: (j['ownerEmail'] as String?)?.trim().isEmpty == true
        ? null
        : (j['ownerEmail'] as String?),
    primaryDomain: (j['primaryDomain'] as String?)?.trim().isEmpty == true
        ? null
        : (j['primaryDomain'] as String?),
    createdAt: TenantUtil.parseTs(j['createdAt']),
    updatedAt: TenantUtil.parseTs(j['updatedAt']),
  );

  Map<String, dynamic> toJson() => {
    'slug': slug,
    'displayName': displayName,
    'primaryColor': primaryColor,
    if (logoPath != null) 'logoPath': logoPath,
    'flags': flags,
    'status': status.value, // ← neat
    'ownerUid': ownerUid,
    'ownerEmail': ownerEmail,
    'primaryDomain': primaryDomain,
    if (createdAt != null) 'createdAt': createdAt,
    if (updatedAt != null) 'updatedAt': updatedAt,
  };
}
