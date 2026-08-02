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

  Future<NotificationSettings> requestPermission() {
    return _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<String?> getToken() async {
    final String? token = await _messaging.getToken();
    final String clean = (token ?? '').trim();

    return clean.isEmpty ? null : clean;
  }

  Future<void> registerDevice({
    required AuthUser user,
    required String token,
  }) async {
    final String cleanToken = token.trim();

    if (cleanToken.isEmpty) return;

    final DocumentReference<Map<String, dynamic>> deviceRef = _deviceRef(
      tenantId: user.tenantId,
      token: cleanToken,
    );

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await deviceRef
        .get();

    final Map<String, dynamic> values = <String, dynamic>{
      'uid': user.uid,
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
      return;
    }

    await deviceRef.set(values, SetOptions(merge: true));
  }

  Future<void> disableDevice({
    required AuthUser user,
    required String token,
  }) async {
    final String cleanToken = token.trim();
    if (cleanToken.isEmpty) return;

    final DocumentReference<Map<String, dynamic>> deviceRef = _deviceRef(
      tenantId: user.tenantId,
      token: cleanToken,
    );

    final DocumentSnapshot<Map<String, dynamic>> snapshot = await deviceRef
        .get();

    if (!snapshot.exists) return;

    await deviceRef.update(<String, dynamic>{
      'enabled': false,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  DocumentReference<Map<String, dynamic>> _deviceRef({
    required String tenantId,
    required String token,
  }) {
    final String deviceId = sha256.convert(utf8.encode(token)).toString();

    return _firestore
        .collection('tenants')
        .doc(tenantId.trim())
        .collection('notification_devices')
        .doc(deviceId);
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
