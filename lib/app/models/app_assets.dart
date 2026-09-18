// lib/app/models/app_assets.dart

import 'package:flutter/foundation.dart';

@immutable
class AppAssets {
  final String bucket;
  final int version;
  final Map<String, String> logos;

  const AppAssets({
    required this.bucket,
    required this.version,
    required this.logos,
  });

  factory AppAssets.fromMap(Map<String, dynamic>? map) {
    final source = map ?? const <String, dynamic>{};

    return AppAssets(
      bucket: source['bucket']?.toString().trim().isNotEmpty == true
          ? source['bucket'].toString().trim()
          : 'afyakit-api.firebasestorage.app',
      version: (source['version'] as num?)?.toInt() ?? 0,
      logos: {
        for (final entry in ((source['logos'] as Map?) ?? const {}).entries)
          entry.key.toString(): entry.value.toString(),
      },
    );
  }

  String? logoUrl({String? prefer}) {
    final raw = _pick(prefer: prefer);

    if (raw == null) {
      return null;
    }

    if (!raw.startsWith('http://') && !raw.startsWith('https://')) {
      return null;
    }

    return _withVersion(raw);
  }

  String? rawLogoValue({String? prefer}) {
    return _pick(prefer: prefer);
  }

  String? _pick({String? prefer}) {
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
}
