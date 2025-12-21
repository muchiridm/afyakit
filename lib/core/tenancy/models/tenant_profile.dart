// lib/core/tenancy/models/tenant_profile.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';

import 'tenant_json.dart';
import 'tenant_features.dart';
import 'tenant_assets.dart';
import 'tenant_details.dart';

/// ─────────────────────────────────────────────
/// The actual Tenant Profile
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

  factory TenantProfile.fromFirestore(String id, Json d) {
    // For v2 tenants we have a nested `profile` map.
    // For older tenants, fields such as tagline/website/email/whatsapp
    // live at the root. Fall back to the whole document so
    // TenantDetails can pick them up.
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

/// Web-specific asset helpers on top of TenantProfile.
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
