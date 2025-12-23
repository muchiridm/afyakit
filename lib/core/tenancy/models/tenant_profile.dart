// lib/core/tenancy/models/tenant_profile.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/tenancy/extensions/tenant_status_x.dart';

import 'tenant_json.dart';
import 'tenant_features.dart';
import 'tenant_assets.dart';
import 'tenant_details.dart';

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

  static String _str(dynamic v, {String fallback = ''}) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? fallback : s;
  }

  static String? _strOrNull(dynamic v) {
    final s = v?.toString().trim();
    return (s == null || s.isEmpty) ? null : s;
  }

  static Json _json(dynamic v) {
    if (v is Map) return Map<String, dynamic>.from(v);
    return const <String, dynamic>{};
  }

  factory TenantProfile.fromFirestore(String id, Json d) {
    // v2 shape: `profile` nested map (client-facing + SEO fields).
    // v1 shape: those fields at the root.
    final Json profileMap = _json(d['profile']).isNotEmpty
        ? _json(d['profile'])
        : d;

    final displayName = _str(d['displayName'], fallback: id);

    final primaryColorHex = _str(
      d['primaryColorHex'] ?? d['primaryColor'],
      fallback: '#2196F3',
    );

    final featuresMap = _json(d['features']);
    final assetsMap = _json(d['assets']);

    final statusStr = _strOrNull(d['status']); // tolerate non-string values
    final status = TenantStatusX.parse(statusStr);

    return TenantProfile(
      id: id,
      displayName: displayName,
      primaryColorHex: primaryColorHex,
      features: TenantFeatures.fromMap(
        featuresMap.isEmpty ? null : featuresMap,
      ),
      assets: TenantAssets.fromMap(assetsMap.isEmpty ? null : assetsMap),
      details: TenantDetails.fromMap(profileMap),
      status: status,
    );
  }

  Color get primaryColor => _colorFromHex(primaryColorHex);

  bool has(String featureKey) => features.enabled(featureKey);

  String? logoUrl({String? prefer}) => assets.logoUrl(prefer: prefer);

  bool get isActive => status.isActive;

  /// Title suitable for browser tab / SEO.
  ///
  /// Priority:
  ///   details.seoTitle → displayName → id
  String get webTitle {
    final seo = details.seoTitle?.trim();
    if (seo != null && seo.isNotEmpty) return seo;
    if (displayName.trim().isNotEmpty) return displayName.trim();
    return id;
  }

  /// Description suitable for <meta name="description">.
  ///
  /// Priority:
  ///   details.seoDescription → tagline → supportNote → empty string
  String get webDescription {
    final seo = details.seoDescription?.trim();
    if (seo != null && seo.isNotEmpty) return seo;

    final tagline = details.tagline?.trim();
    if (tagline != null && tagline.isNotEmpty) return tagline;

    final note = details.supportNote?.trim();
    if (note != null && note.isNotEmpty) return note;

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
