import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';

/// Captures the authenticated user and scope; never borrows a subsequent login.
class NotificationService {
  NotificationService(this.client, this.routes);
  final AfyaKitClient client;
  final AfyaKitRoutes routes;

  static Future<NotificationService> create(
    String tenant,
    String app,
    String uid,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != uid) {
      throw StateError('Notification session unavailable');
    }
    Future<String?> token() async =>
        FirebaseAuth.instance.currentUser?.uid == user.uid
        ? user.getIdToken()
        : null;
    final client = await AfyaKitClient.create(
      baseUrl: apiBaseUrl(tenant),
      appId: app,
      getToken: token,
    );
    return NotificationService(client, AfyaKitRoutes(tenant));
  }

  Future<Map<String, dynamic>> begin(
    String id,
    String token,
    Map<String, dynamic>? previous,
  ) async {
    final response = await client.postUri<Map<String, dynamic>>(
      routes.notificationChallenges(),
      data: {
        'id': id,
        'token': token,
        'platform': kIsWeb
            ? 'web'
            : defaultTargetPlatform == TargetPlatform.android
            ? 'android'
            : 'ios',
        if (previous != null)
          'previous': {
            'id': previous['registrationId'],
            'generation': previous['generation'],
          },
      },
    );
    return response.data!;
  }

  Future<Map<String, dynamic>> confirm(String id, String proof) async {
    final response = await client.postUri<Map<String, dynamic>>(
      routes.notificationChallenge(id, confirm: true),
      data: {'proof': proof},
    );
    return response.data!;
  }

  Future<void> cancel(String id) async {
    await client.deleteUri(routes.notificationChallenge(id));
  }

  Future<void> revoke(Map<String, dynamic> registration) async {
    await client.deleteUri(
      routes.notificationRegistration(registration['registrationId']),
      data: {'generation': registration['generation']},
    );
  }

  Future<bool> validate(Map<String, dynamic> registration) async {
    final response = await client.postUri<Map<String, dynamic>>(
      routes.notificationRegistration(
        registration['registrationId'],
        validate: true,
      ),
      data: {'generation': registration['generation']},
    );
    return response.data?['active'] == true;
  }
}
