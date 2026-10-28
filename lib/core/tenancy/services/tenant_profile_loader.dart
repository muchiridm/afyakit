// lib/core/tenancy/services/tenant_profile_loader.dart

import 'dart:convert';

import 'package:afyakit/core/tenancy/models/tenant_status_x.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/core/tenancy/models/tenant_profile.dart';
import 'package:afyakit/shared/utils/utils.dart';

class TenantProfileLoader {
  TenantProfileLoader(this._db);

  final FirebaseFirestore _db;

  static const String _cachePrefix = 'tenant_profile_v4:';

  Future<TenantProfile> load(String tenantId, {bool useCache = true}) async {
    final cleanTenantId = tenantId.trim().toLowerCase();

    final stopwatch = Stopwatch()..start();

    try {
      final snapshot = await _tenantDocument(cleanTenantId).get();

      if (!snapshot.exists) {
        throw StateError('Tenant "$cleanTenantId" not found');
      }

      final raw = snapshot.data() ?? const <String, dynamic>{};

      final profile = TenantProfile.fromFirestore(cleanTenantId, raw);

      if (!profile.isActive) {
        throw StateError(
          'Tenant "$cleanTenantId" '
          'is ${profile.status.value}',
        );
      }

      await _saveCache(cleanTenantId, profile);

      stopwatch.stop();

      debugPrint(
        '✅ TenantProfileLoader(Firestore) '
        '${stopwatch.elapsedMilliseconds}ms '
        '→ $cleanTenantId',
      );

      return profile;
    } catch (error) {
      debugPrint(
        '⚠️ TenantProfileLoader live fetch failed '
        'for "$cleanTenantId": $error',
      );

      if (!useCache) {
        rethrow;
      }
    }

    final cached = await _readCache(cleanTenantId);

    if (cached != null) {
      if (!cached.isActive) {
        throw StateError(
          'Cached tenant "$cleanTenantId" '
          'is ${cached.status.value}',
        );
      }

      debugPrint(
        '🛟 TenantProfileLoader(cache) '
        '→ $cleanTenantId',
      );

      return cached;
    }

    throw StateError(
      'Unable to load tenant profile '
      '"$cleanTenantId" '
      '(no live data, no cache).',
    );
  }

  Stream<TenantProfile> stream(String tenantId) {
    final cleanTenantId = tenantId.trim().toLowerCase();

    return _tenantDocument(cleanTenantId).snapshots().map((snapshot) {
      if (!snapshot.exists) {
        throw StateError('Tenant "$cleanTenantId" not found');
      }

      final raw = snapshot.data() ?? const <String, dynamic>{};

      final profile = TenantProfile.fromFirestore(cleanTenantId, raw);

      if (!profile.isActive) {
        throw StateError(
          'Tenant "$cleanTenantId" '
          'is ${profile.status.value}',
        );
      }

      // Fire-and-forget cache refresh.
      _saveCache(cleanTenantId, profile);

      return profile;
    });
  }

  DocumentReference<JsonObj> _tenantDocument(String tenantId) {
    return _db.collection('tenants').doc(tenantId);
  }

  Future<void> _saveCache(String tenantId, TenantProfile profile) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = <String, dynamic>{
      'features': profile.features.values,
      'status': profile.status.value,
    };

    await prefs.setString('$_cachePrefix$tenantId', jsonEncode(raw));
  }

  Future<TenantProfile?> _readCache(String tenantId) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = prefs.getString('$_cachePrefix$tenantId');

    if (raw == null || raw.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(raw);

      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);

      return TenantProfile.fromFirestore(tenantId, map);
    } catch (error) {
      debugPrint(
        '⚠️ TenantProfileLoader cache read failed '
        'for "$tenantId": $error',
      );

      return null;
    }
  }
}
