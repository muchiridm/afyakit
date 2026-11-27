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

  static final RegExp _idPattern = RegExp(r'^[a-z0-9][a-z0-9_-]{0,63}$');

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

    debugPrint('[notifications] operation');

    return settings;
  }

  Future<String?> getToken() async {
    try {
      if (kIsWeb && _webVapidKey.trim().isEmpty) {
        debugPrint('[notifications] operation');

        return null;
      }

      final token = await _messaging.getToken(
        vapidKey: kIsWeb ? _webVapidKey : null,
      );

      final cleanToken = token?.trim() ?? '';

      if (cleanToken.isEmpty) {
        debugPrint('[notifications] operation');

        return null;
      }

      debugPrint('[notifications] operation');

      return cleanToken;
    } catch (error) {
      debugPrint('[notifications] operation');

      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Device registration
  // ─────────────────────────────────────────────

  Future<void> registerDevice({
    required AuthUser user,
    required String appId,
    required String token,
  }) async {
    final identity = _resolveIdentity(user: user, appId: appId, token: token);

    if (identity == null) {
      throw StateError(
        'Cannot register notification device: '
        'invalid tenant, app, user or token.',
      );
    }

    final deviceRef = _deviceRef(
      tenantId: identity.tenantId,
      deviceId: identity.deviceId,
    );

    try {
      debugPrint('[notifications] operation');
      late final DocumentSnapshot<Map<String, dynamic>> snapshot;
      try {
        snapshot = await deviceRef.get();
      } on FirebaseException {
        debugPrint('[notifications] operation');
        rethrow;
      }

      // A device document must not silently change
      // ownership between authenticated users.
      if (snapshot.exists) {
        final existingUid = _clean(snapshot.data()?['uid']);

        if (existingUid.isNotEmpty && existingUid != identity.uid) {
          throw StateError(
            'Notification device belongs to '
            'another user.',
          );
        }
      }

      final values = <String, dynamic>{
        'uid': identity.uid,
        'token': identity.token,
        'app_id': identity.appId,
        'platform': _platform,
        'enabled': true,
        'isStaff': user.isStaffResolved,

        if ((user.accountNumber ?? '').trim().isNotEmpty)
          'accountNumber': user.accountNumber!.trim(),

        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (!snapshot.exists) {
        values['createdAt'] = FieldValue.serverTimestamp();
      }

      debugPrint('[notifications] operation');

      try {
        await deviceRef.set(values, SetOptions(merge: true));
      } on FirebaseException {
        debugPrint('[notifications] operation');
        rethrow;
      }

      debugPrint('[notifications] operation');
    } catch (error) {
      debugPrint('[notifications] operation');

      rethrow;
    }
  }

  /// Registers the current token, then disables the previous registration.
  ///
  /// The previous identity is supplied explicitly so switching accounts or
  /// apps never disables another device owned by the newly signed-in user.
  /// This cannot discover stale tokens left by earlier browser sessions.
  Future<void> replaceDeviceToken({
    required AuthUser user,
    required String appId,
    required String token,
    AuthUser? previousUser,
    String? previousAppId,
    String? previousToken,
  }) async {
    await registerDevice(user: user, appId: appId, token: token);

    final oldToken = previousToken?.trim() ?? '';
    final oldApp = previousAppId?.trim().toLowerCase() ?? '';
    final oldUser = previousUser;
    if (oldToken.isEmpty || oldApp.isEmpty || oldUser == null) return;

    final sameRegistration =
        oldUser.tenantId.trim().toLowerCase() ==
            user.tenantId.trim().toLowerCase() &&
        oldUser.uid == user.uid &&
        oldApp == appId.trim().toLowerCase() &&
        oldToken == token.trim();
    if (sameRegistration) return;

    try {
      await disableDevice(user: oldUser, appId: oldApp, token: oldToken);
    } catch (error) {
      // A successful replacement should remain registered even when cleanup
      // is blocked by permissions or an intermittently unavailable network.
      debugPrint('[notifications] operation');
    }
  }

  // ─────────────────────────────────────────────
  // Disable device
  // ─────────────────────────────────────────────

  Future<void> disableDevice({
    required AuthUser user,
    required String appId,
    required String token,
  }) async {
    final identity = _resolveIdentity(
      user: user,
      appId: appId,
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
        debugPrint('[notifications] operation');

        return;
      }

      final data = snapshot.data();

      final registeredUid = _clean(data?['uid']);
      final registeredAppId = _clean(data?['app_id']).toLowerCase();

      if (registeredUid != identity.uid || registeredAppId != identity.appId) {
        debugPrint('[notifications] operation');

        return;
      }

      await deviceRef.update({
        'enabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint('[notifications] operation');
    } catch (error) {
      debugPrint('[notifications] operation');

      rethrow;
    }
  }

  // ─────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────

  _NotificationDeviceIdentity? _resolveIdentity({
    required AuthUser user,
    required String appId,
    required String token,
    bool logInvalid = true,
  }) {
    final cleanToken = token.trim();
    final tenantId = user.tenantId.trim().toLowerCase();
    final cleanAppId = appId.trim().toLowerCase();
    final uid = user.uid.trim();

    if (cleanToken.isEmpty) {
      if (logInvalid) {
        debugPrint('[notifications] operation');
      }

      return null;
    }

    if (!_idPattern.hasMatch(tenantId)) {
      if (logInvalid) {
        debugPrint('[notifications] operation');
      }

      return null;
    }

    if (!_idPattern.hasMatch(cleanAppId)) {
      if (logInvalid) {
        debugPrint('[notifications] operation');
      }

      return null;
    }

    if (uid.isEmpty) {
      if (logInvalid) {
        debugPrint('[notifications] operation');
      }

      return null;
    }

    return _NotificationDeviceIdentity(
      tenantId: tenantId,
      appId: cleanAppId,
      uid: uid,
      token: cleanToken,
      deviceId: _deviceId(uid, cleanAppId, cleanToken),
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

  // Per-user, per-app registration on a shared physical device.
  // FCM tokens identify a browser/app installation, NOT an authenticated user.
  // Include uid so different users can register the same token without
  // reading or overwriting one another's Firestore document.
  //
  // IMPORTANT: The backend must ensure that only the ACTIVE user for a token
  // is targeted when sending notifications. Existing [appId, token] documents
  // require trusted backend migration/disablement before full rollout.
  String _deviceId(String uid, String appId, String token) {
    final input = jsonEncode([uid, appId, token]);

    return sha256.convert(utf8.encode(input)).toString();
  }

  String _clean(Object? value) {
    return value is String ? value.trim() : '';
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
    required this.appId,
    required this.uid,
    required this.token,
    required this.deviceId,
  });

  final String tenantId;
  final String appId;
  final String uid;
  final String token;
  final String deviceId;
}
