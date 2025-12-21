// lib/hq/tenants/models/tenant_assets.dart

import 'package:flutter/foundation.dart';

import 'tenant_json.dart';

/// ─────────────────────────────────────────────
/// Assets (logos, bucket, versioning)
// ─────────────────────────────────────────────
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
