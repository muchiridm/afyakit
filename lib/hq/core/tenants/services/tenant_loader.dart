import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:afyakit/hq/core/tenants/services/tenant_config.dart';

typedef Json = Map<String, dynamic>;

class TenantConfigLoader {
  TenantConfigLoader(this._db);
  final FirebaseFirestore _db;

  static const _cachePrefix = 'tenant_cfg_v1:'; // bump on shape changes

  Future<TenantConfig> load(String slug, {bool useCache = true}) async {
    final sw = Stopwatch()..start();

    // 1) live Firestore
    try {
      final snap = await _db.collection('tenants').doc(slug).get();
      if (!snap.exists) throw StateError('Tenant "$slug" not found');

      final d = snap.data() ?? const {};
      final status = (d['status'] ?? 'active').toString();
      if (status != 'active') throw StateError('Tenant "$slug" is $status');

      final cfg = TenantConfig.fromFirestore(slug, {
        'displayName': d['displayName'],
        'primaryColor': d['primaryColor'] ?? d['primaryColorHex'],
        'logoPath': d['logoPath'],
        'flags': d['flagsPublic'] ?? d['flags'] ?? const <String, dynamic>{},
      });

      await _saveCache(slug, cfg);
      sw.stop();
      debugPrint(
        '✅ TenantLoader(Firestore) ${sw.elapsedMilliseconds}ms → ${cfg.displayName}',
      );
      return cfg;
    } catch (e) {
      debugPrint('⚠️ TenantLoader live fetch failed: $e');
      if (!useCache) rethrow;
    }

    // 2) last-known cache
    final cached = await _readCache(slug);
    if (cached != null) {
      debugPrint('🛟 TenantLoader(cache) → ${cached.displayName}');
      return cached;
    }

    throw StateError('Unable to load tenant "$slug" (no live data, no cache).');
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
