// lib/core/notifications/notification_service.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

class NotificationService {
  NotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  static const String _webVapidKey = String.fromEnvironment(
    'FCM_WEB_VAPID_KEY',
  );

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  // ─────────────────────────────────────────────
  // Permission / token
  // ─────────────────────────────────────────────

  Future<NotificationSettings> requestPermission() async {
    final settings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    debugPrint(
      '🔔 Notification permission '
      'status=${settings.authorizationStatus.name}',
    );

    return settings;
  }

  Future<String?> getToken() async {
    try {
      if (kIsWeb && _webVapidKey.trim().isEmpty) {
        debugPrint(
          '❌ FCM web token unavailable: '
          'FCM_WEB_VAPID_KEY is not configured.',
        );

        return null;
      }

      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );

      final cleanToken = token?.trim() ?? '';

      if (cleanToken.isEmpty) {
        debugPrint(
          '⚠️ FCM token unavailable '
          'platform=$_platform',
        );

        return null;
      }

      debugPrint(
        '🔑 FCM token loaded '
        'platform=$_platform '
        'prefix=${_tokenPrefix(cleanToken)}',
      );

      return cleanToken;
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Failed to load FCM token '
        'platform=$_platform '
        'error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Device registration
  // ─────────────────────────────────────────────

  Future<void> registerDevice({
    required AuthUser user,
    required String token,
  }) async {
    final identity = _resolveIdentity(user: user, token: token);

    if (identity == null) {
      return;
    }

    final deviceRef = _deviceRef(
      tenantId: identity.tenantId,
      deviceId: identity.deviceId,
    );

    try {
      final snapshot = await deviceRef.get();

      final values = <String, dynamic>{
        'uid': identity.uid,
        'token': identity.token,
        'platform': _platform,
        'enabled': true,
        'isStaff': user.isStaffResolved,

        if ((user.contactId ?? '').trim().isNotEmpty)
          'contactId': user.contactId!.trim(),

        if ((user.accountNumber ?? '').trim().isNotEmpty)
          'accountNumber': user.accountNumber!.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        values['createdAt'] = FieldValue.serverTimestamp();
      }

      debugPrint(
        '🔔 Registering notification device '
        'tenant=${identity.tenantId} '
        'uid=${identity.uid} '
        'isStaff=${user.isStaffResolved} '
        'platform=$_platform '
        'exists=${snapshot.exists} '
        'deviceId=${identity.deviceId}',
      );

      await deviceRef.set(values, SetOptions(merge: true));

      debugPrint(
        '✅ Notification device registered '
        'tenant=${identity.tenantId} '
        'uid=${identity.uid} '
        'isStaff=${user.isStaffResolved} '
        'platform=$_platform '
        'deviceId=${identity.deviceId}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Notification device registration failed '
        'tenant=${identity.tenantId} '
        'uid=${identity.uid} '
        'platform=$_platform '
        'deviceId=${identity.deviceId} '
        'error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  Future<void> disableDevice({
    required AuthUser user,
    required String token,
  }) async {
    final identity = _resolveIdentity(
      user: user,
      token: token,
      logInvalid: false,
    );

    if (identity == null) {
      return;
    }

    final deviceRef = _deviceRef(
      tenantId: identity.tenantId,
      deviceId: identity.deviceId,
    );

    try {
      final snapshot = await deviceRef.get();

      if (!snapshot.exists) {
        debugPrint(
          'ℹ️ Notification device disable skipped: '
          'document missing '
          'tenant=${identity.tenantId} '
          'uid=${identity.uid} '
          'deviceId=${identity.deviceId}',
        );

        return;
      }

      final registeredUid = (snapshot.data()?['uid'] as String? ?? '').trim();

      if (registeredUid.isNotEmpty && registeredUid != identity.uid) {
        debugPrint(
          '⚠️ Notification device disable skipped: '
          'UID mismatch '
          'tenant=${identity.tenantId} '
          'currentUid=${identity.uid} '
          'registeredUid=$registeredUid '
          'deviceId=${identity.deviceId}',
        );

        return;
      }

      await deviceRef.update({
        'enabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '🔕 Notification device disabled '
        'tenant=${identity.tenantId} '
        'uid=${identity.uid} '
        'platform=$_platform '
        'deviceId=${identity.deviceId}',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Notification device disable failed '
        'tenant=${identity.tenantId} '
        'uid=${identity.uid} '
        'platform=$_platform '
        'deviceId=${identity.deviceId} '
        'error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);

      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  _NotificationDeviceIdentity? _resolveIdentity({
    required AuthUser user,
    required String token,
    bool logInvalid = true,
  }) {
    final cleanToken = token.trim();
    final tenantId = user.tenantId.trim().toLowerCase();
    final uid = user.uid.trim();

    if (cleanToken.isEmpty) {
      if (logInvalid) {
        debugPrint(
          '⚠️ Notification device operation skipped: '
          'empty FCM token',
        );
      }

      return null;
    }

    if (tenantId.isEmpty) {
      if (logInvalid) {
        debugPrint(
          '⚠️ Notification device operation skipped: '
          'empty tenantId',
        );
      }

      return null;
    }

    if (uid.isEmpty) {
      if (logInvalid) {
        debugPrint(
          '⚠️ Notification device operation skipped: '
          'empty uid',
        );
      }

      return null;
    }

    return _NotificationDeviceIdentity(
      tenantId: tenantId,
      uid: uid,
      token: cleanToken,
      deviceId: _deviceId(cleanToken),
    );
  }

  DocumentReference<Map<String, dynamic>> _deviceRef({
    required String tenantId,
    required String deviceId,
  }) {
    return _firestore
        .collection('tenants')
        .doc(tenantId)
        .collection('notification_devices')
        .doc(deviceId);
  }

  String _deviceId(String token) {
    return sha256.convert(utf8.encode(token)).toString();
  }

  String _tokenPrefix(String token) {
    if (token.length <= 12) {
      return token;
    }

    return '${token.substring(0, 12)}…';
  }

  String get _platform {
    if (kIsWeb) {
      return 'web';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'ios',
      TargetPlatform.linux => 'linux',
      TargetPlatform.windows => 'windows',
      TargetPlatform.fuchsia => 'fuchsia',
    };
  }
}

class _NotificationDeviceIdentity {
  const _NotificationDeviceIdentity({
    required this.tenantId,
    required this.uid,
    required this.token,
    required this.deviceId,
  });

  final String tenantId;
  final String uid;
  final String token;
  final String deviceId;
}
