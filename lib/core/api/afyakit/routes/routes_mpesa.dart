// lib/core/api/afyakit/routes/routes_mpesa.dart

part of 'routes.dart';

extension AfyaKitMpesaRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 📲 M-Pesa (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// POST /api/:tenantId/mpesa/stk/initiate
  Uri mpesaStkInitiate() => _uri('mpesa/stk/initiate');

  /// GET /api/:tenantId/mpesa/payments/:paymentId
  Uri mpesaPaymentStatus(String paymentId) =>
      _uri('mpesa/payments/${_seg(paymentId)}');
}
