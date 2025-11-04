// lib/hq/core/tenants/services/tenant_config_loader.dart
import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/hq/tenants/models/tenant_config.dart';

typedef Json = Map<String, dynamic>;

class TenantConfigLoader {
  TenantConfigLoader(this._db);
  final FirebaseFirestore _db;

  // bump this when you change how we serialize to prefs
  static const _cachePrefix = 'tenant_cfg_v1:';

  /// Fetch once. Tries live Firestore first; if it fails and
  /// `useCache == true` we return last-known good from prefs.
  Future<TenantConfig> load(String slug, {bool useCache = true}) async {
    final sw = Stopwatch()..start();

    // 1) Authoritative live fetch
    try {
      final snap = await _db.collection('tenants').doc(slug).get();
      if (!snap.exists) {
        throw StateError('Tenant "$slug" not found');
      }

      final raw = snap.data() ?? const <String, dynamic>{};
      final status = (raw['status'] ?? 'active').toString();

      if (status != 'active') {
        // we treat non-active tenants as "found but unusable"
        throw StateError('Tenant "$slug" is $status');
      }

      final cfg = _mapToConfig(slug, raw);

      await _saveCache(slug, cfg);
      sw.stop();
      debugPrint(
        '✅ TenantLoader(Firestore) ${sw.elapsedMilliseconds}ms → ${cfg.displayName}',
      );
      return cfg;
    } catch (e) {
      debugPrint('⚠️ TenantLoader live fetch failed for "$slug": $e');
      if (!useCache) rethrow;
    }

    // 2) Fallback to cache
    final cached = await _readCache(slug);
    if (cached != null) {
      debugPrint('🛟 TenantLoader(cache) → ${cached.displayName}');
      return cached;
    }

    throw StateError('Unable to load tenant "$slug" (no live data, no cache).');
  }

  /// Live stream of config (updates cache on change).
  /// Useful for HQ/admin panels.
  Stream<TenantConfig> stream(String slug) {
    return _db.collection('tenants').doc(slug).snapshots().map((s) {
      final raw = s.data() ?? const <String, dynamic>{};
      final cfg = _mapToConfig(slug, raw);
      // fire-and-forget: don't await inside stream map
      _saveCache(slug, cfg);
      return cfg;
    });
  }

  // ────────────────────────────────────────────────────────────
  // Internals
  // ────────────────────────────────────────────────────────────

  TenantConfig _mapToConfig(String slug, Map<String, dynamic> d) {
    // tolerate both primaryColor + primaryColorHex
    final primaryColor = d['primaryColor'] ?? d['primaryColorHex'];

    // tolerate both flagsPublic + flags
    final flags = d['flagsPublic'] ?? d['flags'] ?? const <String, dynamic>{};

    return TenantConfig.fromFirestore(slug, {
      'displayName': d['displayName'],
      'primaryColor': primaryColor,
      'logoPath': d['logoPath'],
      'flags': flags,
    });
  }

  Future<void> _saveCache(String slug, TenantConfig cfg) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('$_cachePrefix$slug', jsonEncode(cfg.toJson()));
  }

  Future<TenantConfig?> _readCache(String slug) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('$_cachePrefix$slug');
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as Json;
      return TenantConfig.fromFirestore(slug, m);
    } catch (_) {
      return null;
    }
  }
}
