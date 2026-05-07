// lib/core/api/afyakit/routes/routes_misc.dart

part of 'routes.dart';

extension AfyaKitMiscRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🏓 Ping
  // ─────────────────────────────────────────────

  Uri ping() => _uri('ping');
}
