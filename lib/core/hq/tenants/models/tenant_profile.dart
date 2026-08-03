// lib/core/hq/tenants/models/tenant_profile.dart

import 'package:flutter/material.dart';

import 'package:afyakit/core/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/shared/utils/utils.dart';

import 'tenant_assets.dart';
import 'tenant_details.dart';
import 'tenant_features.dart';

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

  static String _str(dynamic value, {String fallback = ''}) {
    final string = value?.toString().trim();

    return string == null || string.isEmpty ? fallback : string;
  }

  static String? _strOrNull(dynamic value) {
    final string = value?.toString().trim();

    return string == null || string.isEmpty ? null : string;
  }

  static JsonObj _json(dynamic value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  factory TenantProfile.fromFirestore(String id, JsonObj data) {
    // v2: profile nested map; v1: root fields.
    final nestedProfile = _json(data['profile']);
    final profileMap = nestedProfile.isNotEmpty ? nestedProfile : data;

    final displayName = _str(
      profileMap['displayName'] ?? data['displayName'],
      fallback: id,
    );

    final primaryColorHex = _str(
      profileMap['primaryColorHex'] ??
          profileMap['primaryColor'] ??
          data['primaryColorHex'] ??
          data['primaryColor'],
      fallback: '#2196F3',
    );

    final featuresMap = _json(data['features']);
    final assetsMap = _json(data['assets']);

    final statusString = _strOrNull(data['status']);
    final status = TenantStatusX.parse(statusString);

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

  String get webTitle {
    final seoTitle = details.seoTitle?.trim();

    if (seoTitle != null && seoTitle.isNotEmpty) {
      return seoTitle;
    }

    final name = displayName.trim();

    if (name.isNotEmpty) {
      return name;
    }

    return id;
  }

  String get webDescription {
    final seoDescription = details.seoDescription?.trim();

    if (seoDescription != null && seoDescription.isNotEmpty) {
      return seoDescription;
    }

    final tagline = details.tagline?.trim();

    if (tagline != null && tagline.isNotEmpty) {
      return tagline;
    }

    final supportNote = details.supportNote?.trim();

    if (supportNote != null && supportNote.isNotEmpty) {
      return supportNote;
    }

    return '';
  }
}

Color _colorFromHex(String hex, {String fallback = '#2196F3'}) {
  String sanitize(String value) {
    var sanitized = value.trim();

    if (sanitized.startsWith('#')) {
      sanitized = sanitized.substring(1);
    }

    if (sanitized.startsWith('0x') || sanitized.startsWith('0X')) {
      sanitized = sanitized.substring(2);
    }

    if (sanitized.length == 3) {
      sanitized =
          '${sanitized[0]}${sanitized[0]}'
          '${sanitized[1]}${sanitized[1]}'
          '${sanitized[2]}${sanitized[2]}';
    }

    if (sanitized.length == 6) {
      sanitized = 'FF$sanitized';
    }

    return sanitized;
  }

  final sanitizedHex = sanitize(hex);
  var value = int.tryParse(sanitizedHex, radix: 16);

  if (value == null || sanitizedHex.length != 8) {
    final sanitizedFallback = sanitize(fallback);
    value = int.tryParse(sanitizedFallback, radix: 16) ?? 0xFF2196F3;
  }

  return Color(value);
}

extension TenantProfileWebAssetsX on TenantProfile {
  String get _webAssetBasePath => 'public/$id/branding/web';

  String get _webBucket => assets.bucket.isNotEmpty
      ? assets.bucket
      : 'afyakit-api.firebasestorage.app';

  String get _versionSuffix => assets.version > 0 ? '?v=${assets.version}' : '';

  String get faviconUrl =>
      'https://storage.googleapis.com/'
      '$_webBucket/$_webAssetBasePath/favicon.png$_versionSuffix';

  String get icon192Url =>
      'https://storage.googleapis.com/'
      '$_webBucket/$_webAssetBasePath/icon-192.png$_versionSuffix';

  String get icon512Url =>
      'https://storage.googleapis.com/'
      '$_webBucket/$_webAssetBasePath/icon-512.png$_versionSuffix';

  String get maskableIcon192Url =>
      'https://storage.googleapis.com/'
      '$_webBucket/$_webAssetBasePath/icon-maskable-192.png$_versionSuffix';

  String get maskableIcon512Url =>
      'https://storage.googleapis.com/'
      '$_webBucket/$_webAssetBasePath/icon-maskable-512.png$_versionSuffix';
}
