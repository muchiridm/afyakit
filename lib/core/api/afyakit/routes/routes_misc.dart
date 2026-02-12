part of 'routes.dart';

extension AfyaKitMiscRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🏓 Ping
  // ─────────────────────────────────────────────

  Uri ping() => _uri('ping');

  // ─────────────────────────────────────────────
  // 💊 DawaIndex Proxy (tenant-scoped; authenticated or public depending on BE)
  // ─────────────────────────────────────────────

  Uri diSalesTiles({String? q, String? form, int limit = 50, int offset = 0}) =>
      _uri(
        'dawaindex/v1/sales/tiles',
        query: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (form != null && form.trim().isNotEmpty) 'form': form.trim(),
          'limit': '$limit',
          'offset': '$offset',
        },
      );
}
