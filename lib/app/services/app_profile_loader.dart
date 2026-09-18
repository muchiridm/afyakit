import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/app/models/app_profile.dart';
import 'package:afyakit/shared/utils/utils.dart';

class AppProfileLoader {
  AppProfileLoader(this._db);

  final FirebaseFirestore _db;

  static const String _cachePrefix = 'app_profile_v1:';

  Future<AppProfile> load({
    required String tenantId,
    required String appId,
    bool useCache = true,
  }) async {
    final stopwatch = Stopwatch()..start();

    try {
      final snapshot = await _appDocument(
        tenantId: tenantId,
        appId: appId,
      ).get();

      if (!snapshot.exists) {
        throw StateError('App "$appId" not found for tenant "$tenantId"');
      }

      final raw = snapshot.data() ?? const <String, dynamic>{};

      final profile = AppProfile.fromFirestore(appId, raw);

      if (!profile.active) {
        throw StateError('App "$appId" is inactive');
      }

      await _saveCache(tenantId: tenantId, appId: appId, profile: profile);

      stopwatch.stop();

      debugPrint(
        '✅ AppProfileLoader(Firestore) '
        '${stopwatch.elapsedMilliseconds}ms '
        '→ ${profile.displayName}',
      );

      return profile;
    } catch (error) {
      debugPrint(
        '⚠️ AppProfileLoader live fetch failed '
        'for "$tenantId/$appId": $error',
      );

      if (!useCache) {
        rethrow;
      }
    }

    final cached = await _readCache(tenantId: tenantId, appId: appId);

    if (cached != null) {
      if (!cached.active) {
        throw StateError('Cached app "$appId" is inactive');
      }

      debugPrint(
        '🛟 AppProfileLoader(cache) '
        '→ ${cached.displayName}',
      );

      return cached;
    }

    throw StateError(
      'Unable to load app profile '
      '"$appId" for tenant "$tenantId" '
      '(no live data, no cache).',
    );
  }

  Stream<AppProfile> stream({required String tenantId, required String appId}) {
    return _appDocument(tenantId: tenantId, appId: appId).snapshots().map((
      snapshot,
    ) {
      if (!snapshot.exists) {
        throw StateError('App "$appId" not found for tenant "$tenantId"');
      }

      final raw = snapshot.data() ?? const <String, dynamic>{};

      final profile = AppProfile.fromFirestore(appId, raw);

      if (!profile.active) {
        throw StateError('App "$appId" is inactive');
      }

      _saveCache(tenantId: tenantId, appId: appId, profile: profile);

      return profile;
    });
  }

  DocumentReference<JsonObj> _appDocument({
    required String tenantId,
    required String appId,
  }) {
    return _db
        .collection('tenants')
        .doc(tenantId)
        .collection('apps')
        .doc(appId);
  }

  Future<void> _saveCache({
    required String tenantId,
    required String appId,
    required AppProfile profile,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final raw = <String, dynamic>{
      'displayName': profile.displayName,
      'primaryColorHex': profile.primaryColorHex,
      'features': profile.features.values,
      'assets': {
        'bucket': profile.assets.bucket,
        'version': profile.assets.version,
        if (profile.assets.logos.isNotEmpty) 'logos': profile.assets.logos,
      },
      'profile': {
        'tagline': profile.details.tagline,
        'website': profile.details.website,
        'email': profile.details.email,
        'supportNote': profile.details.supportNote,
        'seoTitle': profile.details.seoTitle,
        'seoDescription': profile.details.seoDescription,
      },
      'status': profile.active ? 'active' : 'inactive',
    };

    await prefs.setString(
      _cacheKey(tenantId: tenantId, appId: appId),
      jsonEncode(raw),
    );
  }

  Future<AppProfile?> _readCache({
    required String tenantId,
    required String appId,
  }) async {
    final prefs = await SharedPreferences.getInstance();

    final string = prefs.getString(_cacheKey(tenantId: tenantId, appId: appId));

    if (string == null || string.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(string);

      if (decoded is! Map) {
        return null;
      }

      final map = Map<String, dynamic>.from(decoded);

      return AppProfile.fromFirestore(appId, map);
    } catch (error) {
      debugPrint(
        '⚠️ AppProfileLoader cache read failed '
        'for "$tenantId/$appId": $error',
      );

      return null;
    }
  }

  String _cacheKey({required String tenantId, required String appId}) {
    return '$_cachePrefix$tenantId:$appId';
  }
}
