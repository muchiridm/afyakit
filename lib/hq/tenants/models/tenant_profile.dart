// lib/hq/tenants/models/tenant_profile.dart

import 'package:flutter/material.dart';
import 'package:afyakit/hq/tenants/extensions/tenant_status_x.dart';

typedef Json = Map<String, dynamic>;

/// ─────────────────────────────────────────────
/// Features (boolean gates)
/// ─────────────────────────────────────────────
@immutable
class TenantFeatures {
  final Map<String, bool> features;

  const TenantFeatures(this.features);

  factory TenantFeatures.fromMap(Map<String, dynamic>? m) {
    final src = m ?? const <String, dynamic>{};

    bool toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    return TenantFeatures({
      for (final e in src.entries) e.key: toBool(e.value),
    });
  }

  bool enabled(String key) => features[key] == true;
}

/// ─────────────────────────────────────────────
/// Assets (logos, bucket, versioning)
/// ─────────────────────────────────────────────
@immutable
class TenantAssets {
  /// Google Cloud Storage bucket (or host-equivalent) for this tenant's assets.
  final String bucket;

  /// Cache-busting version. When you bump this, all generated URLs get ?v=N.
  final int version;

  /// Arbitrary logical keys → paths in the bucket.
  ///
  /// Common keys:
  ///   - "primary"  : main logo
  ///   - "appbar"   : compact/logo for app bar
  ///   - "favicon"  : favicon for web
  ///   - "icon192"  : 192×192 PWA / Apple icon
  ///   - "icon512"  : 512×512 PWA icon
  final Map<String, String> logos;

  const TenantAssets({
    required this.bucket,
    required this.version,
    required this.logos,
  });

  factory TenantAssets.fromMap(Json? m) {
    final x = (m ?? const <String, dynamic>{});
    return TenantAssets(
      bucket: (x['bucket'] as String?) ?? 'afyakit-api.firebasestorage.app',
      version: (x['version'] as num?)?.toInt() ?? 0,
      logos: {
        for (final e in ((x['logos'] as Map?) ?? const {}).entries)
          '${e.key}': '${e.value}',
      },
    );
  }

  /// Generic URL builder for any logical logo key.
  ///
  /// If [prefer] is provided, that key is used when present; otherwise
  /// falls back to "appbar" → "primary".
  String? logoUrl({String? prefer}) {
    final path = (prefer != null && (logos[prefer] ?? '').isNotEmpty)
        ? logos[prefer]
        : (logos['appbar'] ?? logos['primary']);
    if (path == null || path.isEmpty) return null;

    final base = path.startsWith('http')
        ? path
        : path.startsWith('gs://')
        ? path.replaceFirst('gs://', 'https://storage.googleapis.com/')
        : 'https://storage.googleapis.com/$bucket/$path';

    return version > 0
        ? (base.contains('?') ? '$base&v=$version' : '$base?v=$version')
        : base;
  }
}

/// Convenience accessors for web chrome assets.
extension TenantAssetsWebX on TenantAssets {
  /// Favicon for web tab / browser chrome.
  String? get faviconUrl => logoUrl(prefer: 'favicon');

  /// 192×192 icon for PWA / Apple touch icon.
  String? get icon192Url => logoUrl(prefer: 'icon192');

  /// 512×512 icon for PWA manifest.
  String? get icon512Url => logoUrl(prefer: 'icon512');
}

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

/// ─────────────────────────────────────────────
/// The actual v2 Tenant Profile
/// ─────────────────────────────────────────────
@immutable
class TenantProfile {
  final String id;
  final String displayName;
  final String primaryColorHex;
  final TenantFeatures features;
  final TenantAssets assets;
  final TenantDetails details;
  final TenantStatus status;

  const TenantProfile({
    required this.id,
    required this.displayName,
    required this.primaryColorHex,
    required this.features,
    required this.assets,
    required this.details,
    this.status = TenantStatus.active,
  });

  // lib/hq/tenants/models/tenant_profile.dart

  factory TenantProfile.fromFirestore(String id, Json d) {
    // For v2 tenants we have a nested `profile` map.
    // For older tenants (like your DawaPap doc in the screenshot),
    // fields such as tagline/website/email/whatsapp live at the root.
    // Fall back to the whole document so TenantDetails can pick them up.
    final Json profileMap =
        (d['profile'] as Map?)?.cast<String, dynamic>() ?? d;

    return TenantProfile(
      id: id,
      displayName: (d['displayName'] ?? id).toString(),
      primaryColorHex: (d['primaryColorHex'] ?? d['primaryColor'] ?? '#2196F3')
          .toString(),
      features: TenantFeatures.fromMap(
        (d['features'] as Map?)?.cast<String, dynamic>(),
      ),
      assets: TenantAssets.fromMap(
        (d['assets'] as Map?)?.cast<String, dynamic>(),
      ),
      // ⬇️ now sees `tagline`, `website`, `email`, etc. even if they’re root-level
      details: TenantDetails.fromMap(profileMap),
      status: TenantStatusX.parse(d['status'] as String?),
    );
  }

  Color get primaryColor => _colorFromHex(primaryColorHex);

  bool has(String featureKey) => features.enabled(featureKey);

  String? logoUrl({String? prefer}) => assets.logoUrl(prefer: prefer);

  bool get isActive => status.isActive;

  /// Title suitable for browser tab / SEO.
  ///
  /// Priority:
  ///   profile.details.seoTitle → displayName → id
  String get webTitle => details.seoTitle?.trim().isNotEmpty == true
      ? details.seoTitle!.trim()
      : (displayName.isNotEmpty ? displayName : id);

  /// Description suitable for <meta name="description">.
  ///
  /// Priority:
  ///   profile.details.seoDescription → tagline → supportNote → empty string
  String get webDescription {
    if (details.seoDescription != null &&
        details.seoDescription!.trim().isNotEmpty) {
      return details.seoDescription!.trim();
    }
    if (details.tagline != null && details.tagline!.trim().isNotEmpty) {
      return details.tagline!.trim();
    }
    if (details.supportNote != null && details.supportNote!.trim().isNotEmpty) {
      return details.supportNote!.trim();
    }
    return '';
  }
}

/// Local, self-contained color parser
Color _colorFromHex(String hex, {String fallback = '#2196F3'}) {
  String sanitize(String s) {
    var h = s.trim();
    if (h.startsWith('#')) h = h.substring(1);
    if (h.startsWith('0x') || h.startsWith('0X')) h = h.substring(2);
    if (h.length == 3) {
      h = '${h[0]}${h[0]}${h[1]}${h[1]}${h[2]}${h[2]}'; // #RGB → RRGGBB
    }
    if (h.length == 6) {
      h = 'FF$h'; // add alpha
    }
    return h;
  }

  String h = sanitize(hex);
  int? value = int.tryParse(h, radix: 16);

  if (value == null || h.length != 8) {
    final fb = sanitize(fallback);
    value = int.tryParse(fb, radix: 16) ?? 0xFF2196F3;
  }

  return Color(value);
}

// lib/hq/tenants/models/tenant_profile.dart (add at bottom)

extension TenantProfileWebAssetsX on TenantProfile {
  /// Where web assets live in Storage for this tenant.
  /// public/{tenantSlug}/web/...
  String get _webAssetBasePath => 'public/$id/web';

  String get _webBucket => assets.bucket.isNotEmpty
      ? assets.bucket
      : 'afyakit-api.firebasestorage.app';

  String get _versionSuffix => assets.version > 0 ? '?v=${assets.version}' : '';

  /// favicon.png
  String get faviconUrl =>
      'https://storage.googleapis.com/$_webBucket/$_webAssetBasePath/favicon.png$_versionSuffix';

  /// icon-192.png
  String get icon192Url =>
      'https://storage.googleapis.com/$_webBucket/$_webAssetBasePath/icon-192.png$_versionSuffix';

  /// icon-512.png
  String get icon512Url =>
      'https://storage.googleapis.com/$_webBucket/$_webAssetBasePath/icon-512.png$_versionSuffix';
}
