import 'package:flutter/foundation.dart';

@immutable
class BrandingAssets {
  final String bucket;
  final int version;

  /// Asset keys:
  ///
  /// primary
  /// secondary
  /// appbar (legacy/optional)
  /// favicon
  /// icon192
  /// icon512
  /// maskableIcon192
  /// maskableIcon512
  ///
  /// Values are resolved HTTP(S) image URLs.
  final Map<String, String> logos;

  const BrandingAssets({
    required this.bucket,
    required this.version,
    required this.logos,
  });

  factory BrandingAssets.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    final rawBucket = source['bucket']?.toString().trim();

    final rawVersion = source['version'];

    final rawLogos = source['logos'] as Map? ?? const {};

    return BrandingAssets(
      bucket: rawBucket == null || rawBucket.isEmpty
          ? 'afyakit-api.firebasestorage.app'
          : rawBucket,
      version: rawVersion is num ? rawVersion.toInt() : 0,
      logos: {
        for (final entry in rawLogos.entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  // ─────────────────────────────────────────
  // App logos
  // ─────────────────────────────────────────

  /// Header and general app branding.
  ///
  /// public/{tenantId}/{appId}/branding/
  /// logos/logo-primary.png
  String? get primaryLogoUrl => _exactUrl('primary');

  /// Splash screen.
  ///
  /// public/{tenantId}/{appId}/branding/
  /// logos/logo-secondary.png
  String? get secondaryLogoUrl => _exactUrl('secondary');

  /// Optional legacy app-bar logo.
  String? get appBarLogoUrl => _exactUrl('appbar');

  /// Backwards-compatible in-app logo lookup.
  ///
  /// preferred → appbar → primary
  ///
  /// Use primaryLogoUrl or secondaryLogoUrl
  /// when the exact image is required.
  String? logoUrl({String? prefer}) {
    return _resolvedHttpUrl(_pickLogoRaw(prefer: prefer));
  }

  String? rawLogoValue({String? prefer}) {
    return _pickLogoRaw(prefer: prefer);
  }

  // ─────────────────────────────────────────
  // Browser and PWA assets
  // ─────────────────────────────────────────

  String? get faviconUrl => _exactUrl('favicon');

  String? get icon192Url => _exactUrl('icon192');

  String? get icon512Url => _exactUrl('icon512');

  String? get maskableIcon192Url => _exactUrl('maskableIcon192');

  String? get maskableIcon512Url => _exactUrl('maskableIcon512');

  // ─────────────────────────────────────────
  // Internal URL resolution
  // ─────────────────────────────────────────

  String? _exactUrl(String key) {
    return _resolvedHttpUrl(logos[key]);
  }

  String? _pickLogoRaw({String? prefer}) {
    if (prefer != null) {
      final preferred = (logos[prefer] ?? '').trim();

      if (preferred.isNotEmpty) {
        return preferred;
      }
    }

    final appBar = (logos['appbar'] ?? '').trim();

    if (appBar.isNotEmpty) {
      return appBar;
    }

    final primary = (logos['primary'] ?? '').trim();

    return primary.isEmpty ? null : primary;
  }

  String? _resolvedHttpUrl(String? raw) {
    final value = raw?.trim();

    if (value == null || value.isEmpty || !_isHttpUrl(value)) {
      return null;
    }

    return _withVersion(value);
  }

  String _withVersion(String url) {
    if (version <= 0) {
      return url;
    }

    return url.contains('?') ? '$url&v=$version' : '$url?v=$version';
  }

  bool _isHttpUrl(String value) {
    final uri = Uri.tryParse(value);

    return uri != null &&
        (uri.scheme == 'http' || uri.scheme == 'https') &&
        uri.host.isNotEmpty;
  }
}
