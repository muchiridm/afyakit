// lib/hq/tenants/models/tenant_assets.dart

import 'package:flutter/foundation.dart';

import 'tenant_json.dart';

@immutable
class TenantAssets {
  /// Firebase Storage bucket host (e.g. "afyakit-api.firebasestorage.app")
  final String bucket;

  /// Cache-busting version. When you bump this, URLs get ?v=N (or &v=N).
  final int version;

  /// Logical keys → stored values.
  ///
  /// RECOMMENDED stored values (web-safe):
  ///   - Full https download URL from Firebase Storage:
  ///     https://firebasestorage.googleapis.com/v0/b/<bucket>/o/<urlencodedPath>?alt=media&token=...
  ///
  /// Legacy values we may still encounter:
  ///   - "gs://bucket/path/to/object"
  ///   - "public/tenant/web/icon-192.png"
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

  /// Resolve a preferred key -> actual stored raw value.
  String? _pickRaw({String? prefer}) {
    String? raw;
    if (prefer != null) {
      final v = (logos[prefer] ?? '').trim();
      if (v.isNotEmpty) raw = v;
    }
    raw ??= (logos['appbar'] ?? '').trim();
    if (raw.isEmpty) raw = (logos['primary'] ?? '').trim();
    return raw.isEmpty ? null : raw;
  }

  /// Append version query param for cache busting.
  String _withVersion(String url) {
    if (version <= 0) return url;
    return url.contains('?') ? '$url&v=$version' : '$url?v=$version';
  }

  bool _isHttpUrl(String s) =>
      s.startsWith('http://') || s.startsWith('https://');

  /// ✅ Main public method: returns a URL ONLY if it is web-safe.
  ///
  /// - If stored value is already https://... → returns it (+ ?v=)
  /// - Otherwise returns null (because gs:// and bucket paths cannot be used
  ///   safely in browsers without either public GCS access + CORS OR a download token).
  String? logoUrl({String? prefer}) {
    final raw = _pickRaw(prefer: prefer);
    if (raw == null) return null;

    if (_isHttpUrl(raw)) {
      return _withVersion(raw);
    }

    // Legacy cases:
    // - gs://...
    // - public/...
    //
    // We intentionally DO NOT convert these to storage.googleapis.com URLs.
    // That route causes CORS/403 problems unless you open up bucket CORS + public reads.
    return null;
  }

  /// If you want a debugging helper (optional): shows what was stored.
  String? rawLogoValue({String? prefer}) => _pickRaw(prefer: prefer);
}

/// Convenience accessors for web chrome assets.
extension TenantAssetsWebX on TenantAssets {
  String? get faviconUrl => logoUrl(prefer: 'favicon');
  String? get icon192Url => logoUrl(prefer: 'icon192');
  String? get icon512Url => logoUrl(prefer: 'icon512');
}
