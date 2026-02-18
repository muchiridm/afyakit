// lib/hq/tenants/services/tenant_profile_loader.dart

import 'dart:convert';

import 'package:afyakit/core/hq/tenants/extensions/tenant_status_x.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/core/hq/tenants/models/tenant_profile.dart';

class TenantProfileLoader {
  TenantProfileLoader(this._db);
  final FirebaseFirestore _db;

  // bump this if you change how we serialize v2
  static const _cachePrefix = 'tenant_profile_v2:';

  /// Fetch once from Firestore, fall back to cache (same behaviour as v1).
  Future<TenantProfile> load(String tenantId, {bool useCache = true}) async {
    final sw = Stopwatch()..start();

    // 1) try live
    try {
      final snap = await _db.collection('tenants').doc(tenantId).get();
      if (!snap.exists) {
        throw StateError('Tenant "$tenantId" not found');
      }

      final raw = snap.data() ?? const <String, dynamic>{};
      // in v2 we might not even have a "status", but let's tolerate it
      final status = (raw['status'] ?? 'active').toString();
      if (status != 'active') {
        throw StateError('Tenant "$tenantId" is $status');
      }

      final profile = TenantProfile.fromFirestore(tenantId, raw);

      await _saveCache(tenantId, profile);
      sw.stop();
      debugPrint(
        '✅ TenantProfileLoader(Firestore) ${sw.elapsedMilliseconds}ms → ${profile.displayName}',
      );
      return profile;
    } catch (e) {
      debugPrint(
        '⚠️ TenantProfileLoader live fetch failed for "$tenantId": $e',
      );
      if (!useCache) rethrow;
    }

    // 2) try cache
    final cached = await _readCache(tenantId);
    if (cached != null) {
      debugPrint('🛟 TenantProfileLoader(cache) → ${cached.displayName}');
      return cached;
    }

    throw StateError(
      'Unable to load tenant profile "$tenantId" (no live data, no cache).',
    );
  }

  /// Live stream of tenant profile, and we update cache on change.
  Stream<TenantProfile> stream(String tenantId) {
    return _db.collection('tenants').doc(tenantId).snapshots().map((s) {
      final raw = s.data() ?? const <String, dynamic>{};
      final profile = TenantProfile.fromFirestore(tenantId, raw);
      // fire-and-forget
      _saveCache(tenantId, profile);
      return profile;
    });
  }

  // ────────────────────────────────────────────────────────────
  // internals
  // ────────────────────────────────────────────────────────────

  Future<void> _saveCache(String tenantId, TenantProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = {
      'displayName': profile.displayName,
      'primaryColorHex': profile.primaryColorHex,
      // 👇 write the new shape
      'features': profile.features.features,
      'assets': profile.assets.logos.isEmpty
          ? {'bucket': profile.assets.bucket, 'version': profile.assets.version}
          : {
              'bucket': profile.assets.bucket,
              'version': profile.assets.version,
              'logos': profile.assets.logos,
            },
      'profile': {
        'tagline': profile.details.tagline,
        'website': profile.details.website,
        'email': profile.details.email,
        'whatsapp': profile.details.whatsapp,
        'currency': profile.details.currency,
        'locale': profile.details.locale,
        'supportNote': profile.details.supportNote,
        'social': profile.details.social,
        'hours': profile.details.hours,
        'address': profile.details.address,
        'compliance': profile.details.compliance,
        'payments': profile.details.payments,
      },
      // optional but nice to keep
      'status': profile.status.value,
    };

    await prefs.setString('$_cachePrefix$tenantId', jsonEncode(raw));
  }

  Future<TenantProfile?> _readCache(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();
    final s = prefs.getString('$_cachePrefix$tenantId');
    if (s == null || s.isEmpty) return null;
    try {
      final m = jsonDecode(s) as JsonObj;
      return TenantProfile.fromFirestore(tenantId, m);
    } catch (_) {
      return null;
    }
  }
}
