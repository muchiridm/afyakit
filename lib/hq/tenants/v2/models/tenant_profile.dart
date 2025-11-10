// lib/hq/tenants/models/tenant_profile.dart
import 'package:flutter/material.dart';
import 'package:afyakit/hq/tenants/v2/extensions/tenant_status_x.dart';

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

    bool _toBool(dynamic v) {
      if (v == null) return false;
      if (v is bool) return v;
      if (v is num) return v != 0;
      if (v is String) return v.toLowerCase() == 'true';
      return false;
    }

    return TenantFeatures({
      for (final e in src.entries) e.key: _toBool(e.value),
    });
  }

  bool enabled(String key) => features[key] == true;
}

/// ─────────────────────────────────────────────
/// Assets (logos, bucket, versioning)
/// ─────────────────────────────────────────────
@immutable
class TenantAssets {
  final String bucket;
  final int version;
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

/// ─────────────────────────────────────────────
/// Details (client-facing info)
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

  factory TenantProfile.fromFirestore(String id, Json d) {
    return TenantProfile(
      id: id,
      displayName: (d['displayName'] ?? id).toString(),
      primaryColorHex: (d['primaryColorHex'] ?? d['primaryColor'] ?? '#2196F3')
          .toString(),
      // ← read only "features" from Firestore
      features: TenantFeatures.fromMap(
        (d['features'] as Map?)?.cast<String, dynamic>(),
      ),
      assets: TenantAssets.fromMap(
        (d['assets'] as Map?)?.cast<String, dynamic>(),
      ),
      details: TenantDetails.fromMap(
        (d['profile'] as Map?)?.cast<String, dynamic>(),
      ),
      status: TenantStatusX.parse(d['status'] as String?),
    );
  }

  Color get primaryColor => _colorFromHex(primaryColorHex);

  bool has(String featureKey) => features.enabled(featureKey);

  String? logoUrl({String? prefer}) => assets.logoUrl(prefer: prefer);

  bool get isActive => status.isActive;
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
