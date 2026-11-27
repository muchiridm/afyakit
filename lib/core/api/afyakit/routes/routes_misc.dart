// lib/core/api/afyakit/routes/routes_misc.dart

part of 'routes.dart';

extension AfyaKitMiscRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🏓 Ping
  // ─────────────────────────────────────────────

  Uri ping() => _uri('ping');
}

extension NotificationRoutes on AfyaKitRoutes {
  Uri notificationChallenges() => _uri('notifications/registration-challenges');
  Uri notificationChallenge(String id, {bool confirm = false}) => _uri(
    'notifications/registration-challenges/${Uri.encodeComponent(id)}${confirm ? '/confirm' : ''}',
  );
  Uri notificationRegistration(String id, {bool validate = false}) => _uri(
    'notifications/registrations/${Uri.encodeComponent(id)}${validate ? '/validate' : ''}',
  );
}
