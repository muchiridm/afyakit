// lib/features/messaging/notifications/chat_notification_service.dart

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'package:afyakit/core/auth/shared/models/auth_user_model.dart';

class ChatNotificationService {
  ChatNotificationService({
    FirebaseFirestore? firestore,
    FirebaseMessaging? messaging,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _messaging = messaging ?? FirebaseMessaging.instance;

  final FirebaseFirestore _firestore;
  final FirebaseMessaging _messaging;

  Stream<String> get onTokenRefresh => _messaging.onTokenRefresh;

  Future<NotificationSettings> requestPermission() async {
    final NotificationSettings settings = await _messaging.requestPermission(
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
      final String? token = await _messaging.getToken();
      final String cleanToken = (token ?? '').trim();

      if (cleanToken.isEmpty) {
        debugPrint('⚠️ FCM token unavailable');
        return null;
      }

      debugPrint(
        '🔑 FCM token loaded '
        'prefix=${_tokenPrefix(cleanToken)}',
      );

      return cleanToken;
    } catch (error, stackTrace) {
      debugPrint('❌ Failed to load FCM token: $error');
      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
  }

  Future<void> registerDevice({
    required AuthUser user,
    required String token,
  }) async {
    final String cleanToken = token.trim();
    final String tenantId = user.tenantId.trim().toLowerCase();
    final String uid = user.uid.trim();

    if (cleanToken.isEmpty) {
      debugPrint('⚠️ Device registration skipped: empty FCM token');
      return;
    }

    if (tenantId.isEmpty) {
      debugPrint('⚠️ Device registration skipped: empty tenantId');
      return;
    }

    if (uid.isEmpty) {
      debugPrint('⚠️ Device registration skipped: empty uid');
      return;
    }

    final String deviceId = _deviceId(cleanToken);

    final DocumentReference<Map<String, dynamic>> deviceRef = _deviceRef(
      tenantId: tenantId,
      deviceId: deviceId,
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await deviceRef
          .get();

      final Map<String, dynamic> values = <String, dynamic>{
        'uid': uid,
        'token': cleanToken,
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

        await deviceRef.set(values);
      } else {
        await deviceRef.set(values, SetOptions(merge: true));
      }

      debugPrint(
        '✅ Notification device registered '
        'tenant=$tenantId '
        'uid=$uid '
        'isStaff=${user.isStaffResolved} '
        'platform=$_platform '
        'deviceId=$deviceId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Notification device registration failed '
        'tenant=$tenantId '
        'uid=$uid '
        'deviceId=$deviceId '
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
    final String cleanToken = token.trim();
    final String tenantId = user.tenantId.trim().toLowerCase();
    final String uid = user.uid.trim();

    if (cleanToken.isEmpty || tenantId.isEmpty || uid.isEmpty) {
      return;
    }

    final String deviceId = _deviceId(cleanToken);

    final DocumentReference<Map<String, dynamic>> deviceRef = _deviceRef(
      tenantId: tenantId,
      deviceId: deviceId,
    );

    try {
      final DocumentSnapshot<Map<String, dynamic>> snapshot = await deviceRef
          .get();

      if (!snapshot.exists) {
        debugPrint(
          'ℹ️ Notification device disable skipped: document missing '
          'tenant=$tenantId '
          'uid=$uid '
          'deviceId=$deviceId',
        );

        return;
      }

      final Map<String, dynamic>? values = snapshot.data();
      final String registeredUid = (values?['uid'] as String? ?? '').trim();

      if (registeredUid.isNotEmpty && registeredUid != uid) {
        debugPrint(
          '⚠️ Notification device disable skipped: UID mismatch '
          'tenant=$tenantId '
          'currentUid=$uid '
          'registeredUid=$registeredUid '
          'deviceId=$deviceId',
        );

        return;
      }

      await deviceRef.update(<String, dynamic>{
        'enabled': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      debugPrint(
        '🔕 Notification device disabled '
        'tenant=$tenantId '
        'uid=$uid '
        'deviceId=$deviceId',
      );
    } catch (error, stackTrace) {
      debugPrint(
        '❌ Notification device disable failed '
        'tenant=$tenantId '
        'uid=$uid '
        'deviceId=$deviceId '
        'error=$error',
      );

      debugPrintStack(stackTrace: stackTrace);
      rethrow;
    }
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
    if (token.length <= 12) return token;

    return '${token.substring(0, 12)}…';
  }

  String get _platform {
    if (kIsWeb) return 'web';

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'android',
      TargetPlatform.iOS => 'ios',
      TargetPlatform.macOS => 'ios',
      _ => 'web',
    };
  }
}
