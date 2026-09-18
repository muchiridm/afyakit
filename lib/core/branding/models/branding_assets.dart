// lib/core/branding/models/branding_assets.dart

import 'package:flutter/foundation.dart';

@immutable
class BrandingAssets {
  final String bucket;
  final int version;
  final Map<String, String> logos;

  const BrandingAssets({
    required this.bucket,
    required this.version,
    required this.logos,
  });

  factory BrandingAssets.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    final rawBucket = source['bucket']?.toString().trim();

    return BrandingAssets(
      bucket: rawBucket == null || rawBucket.isEmpty
          ? 'afyakit-api.firebasestorage.app'
          : rawBucket,
      version: (source['version'] as num?)?.toInt() ?? 0,
      logos: {
        for (final entry in ((source['logos'] as Map?) ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  String? logoUrl({String? prefer}) {
    final raw = _pickRaw(prefer: prefer);

    if (raw == null) return null;

    if (!_isHttpUrl(raw)) {
      return null;
    }

    return _withVersion(raw);
  }

  String? rawLogoValue({String? prefer}) {
    return _pickRaw(prefer: prefer);
  }

  String? get faviconUrl => logoUrl(prefer: 'favicon');

  String? get icon192Url => logoUrl(prefer: 'icon192');

  String? get icon512Url => logoUrl(prefer: 'icon512');

  String? get maskableIcon192Url => logoUrl(prefer: 'maskableIcon192');

  String? get maskableIcon512Url => logoUrl(prefer: 'maskableIcon512');

  String? _pickRaw({String? prefer}) {
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

  String _withVersion(String url) {
    if (version <= 0) {
      return url;
    }

    return url.contains('?') ? '$url&v=$version' : '$url?v=$version';
  }

  bool _isHttpUrl(String value) {
    return value.startsWith('http://') || value.startsWith('https://');
  }
}
