// lib/app/models/app_profile.dart

import 'package:flutter/material.dart';

import 'package:afyakit/app/models/app_details.dart';
import 'package:afyakit/core/branding/models/branding_assets.dart';
import 'package:afyakit/core/capabilities/feature_set.dart';
import 'package:afyakit/shared/utils/color_utils.dart';
import 'package:afyakit/shared/utils/utils.dart';

@immutable
class AppProfile {
  final String id;

  /// Product/application name.
  final String displayName;

  /// Product branding.
  final String primaryColorHex;

  /// Feature exposure for this app.
  ///
  /// Must remain a subset of the parent tenant's capability set.
  final FeatureSet features;

  final BrandingAssets assets;

  final AppDetails details;

  final bool active;

  const AppProfile({
    required this.id,
    required this.displayName,
    required this.primaryColorHex,
    required this.features,
    required this.assets,
    required this.details,
    this.active = true,
  });

  factory AppProfile.fromFirestore(String id, JsonObj data) {
    final nestedProfile = _json(data['profile']);

    final profileMap = nestedProfile.isNotEmpty ? nestedProfile : data;

    final displayName = _string(
      profileMap['displayName'] ?? data['displayName'],
      fallback: id,
    );

    final primaryColorHex = _string(
      profileMap['primaryColorHex'] ??
          profileMap['primaryColor'] ??
          data['primaryColorHex'] ??
          data['primaryColor'],
      fallback: '#2196F3',
    );

    final status = data['status']?.toString().trim().toLowerCase();

    final active = status == null
        ? _bool(data['active'], fallback: true)
        : status == 'active';

    return AppProfile(
      id: id,
      displayName: displayName,
      primaryColorHex: primaryColorHex,
      features: FeatureSet.fromMap(_json(data['features'])),
      assets: BrandingAssets.fromMap(_json(data['assets'])),
      details: AppDetails.fromMap(profileMap),
      active: active,
    );
  }

  Color get primaryColor {
    return colorFromHex(primaryColorHex);
  }

  bool has(String featureKey) {
    return features.enabled(featureKey);
  }

  String? logoUrl({String? prefer}) {
    return assets.logoUrl(prefer: prefer);
  }

  String get webTitle {
    final seoTitle = details.seoTitle?.trim();

    if (seoTitle != null && seoTitle.isNotEmpty) {
      return seoTitle;
    }

    final name = displayName.trim();

    return name.isNotEmpty ? name : id;
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

  static String _string(Object? value, {String fallback = ''}) {
    final text = value?.toString().trim();

    return text == null || text.isEmpty ? fallback : text;
  }

  static JsonObj _json(Object? value) {
    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return const <String, dynamic>{};
  }

  static bool _bool(Object? value, {bool fallback = false}) {
    if (value == null) {
      return fallback;
    }

    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    if (value is String) {
      switch (value.trim().toLowerCase()) {
        case 'true':
        case '1':
        case 'active':
        case 'enabled':
          return true;

        case 'false':
        case '0':
        case 'inactive':
        case 'disabled':
          return false;
      }
    }

    return fallback;
  }
}
