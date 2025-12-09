// lib/hq/tenants/models/tenant_details.dart

import 'package:flutter/foundation.dart';

import 'tenant_json.dart';

/// ─────────────────────────────────────────────
/// Details (client-facing info + SEO)
/// ─────────────────────────────────────────────
@immutable
class TenantDetails {
  final String? tagline;
  final String? website;
  final String? email;
  final String? whatsapp;

  final String currency;
  final String? locale;
  final String? supportNote;

  /// Optional, tenant-controlled SEO title for the site.
  ///
  /// If null, we can fall back to [TenantProfile.displayName] or [tagline].
  final String? seoTitle;

  /// Optional, tenant-controlled SEO / site description.
  ///
  /// If null, we can fall back to [tagline] or [supportNote].
  final String? seoDescription;

  final Map<String, String> social;
  final Map<String, String> hours;
  final Json address;
  final Json compliance;
  final Json payments;

  const TenantDetails({
    this.tagline,
    this.website,
    this.email,
    this.whatsapp,
    required this.currency,
    this.locale,
    this.supportNote,
    this.seoTitle,
    this.seoDescription,
    required this.social,
    required this.hours,
    required this.address,
    required this.compliance,
    required this.payments,
  });

  factory TenantDetails.fromMap(Json? m) {
    final x = (m ?? const <String, dynamic>{});

    Map<String, String> toStrMap(Map? src) => {
      for (final e in (src ?? const {}).entries) '${e.key}': '${e.value}',
    };

    return TenantDetails(
      tagline: x['tagline'] as String?,
      website: x['website'] as String?,
      email: x['email'] as String?,
      whatsapp: x['whatsapp'] as String?,
      currency: (x['currency'] as String?) ?? 'KES',
      locale: x['locale'] as String?,
      supportNote: x['supportNote'] as String?,

      // SEO fields (all optional)
      seoTitle: x['seoTitle'] as String?,
      seoDescription: x['seoDescription'] as String?,

      social: toStrMap(x['social'] as Map?),
      hours: toStrMap(x['hours'] as Map?),
      address: Map<String, dynamic>.from((x['address'] as Map?) ?? const {}),
      compliance: Map<String, dynamic>.from(
        (x['compliance'] as Map?) ?? const {},
      ),
      payments: Map<String, dynamic>.from((x['payments'] as Map?) ?? const {}),
    );
  }

  // ───── mobile money (explicit) ─────
  String? get mobileMoneyName => payments['mobileMoneyName'] as String?;
  String? get mobileMoneyAccount => payments['mobileMoneyAccount'] as String?;
  String? get mobileMoneyNumber => payments['mobileMoneyNumber'] as String?;

  // ───── registration number (explicit) ─────
  String? get registrationNumber => compliance['registrationNumber'] as String?;

  // bank is intentionally not exposed
}
