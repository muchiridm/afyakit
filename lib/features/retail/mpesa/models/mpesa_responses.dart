// lib/features/retail/payments/mpesa/models/mpesa_responses.dart

import '../../../../shared/utils/utils.dart';
import 'mpesa_payment.dart';

class MpesaInitiateResult {
  const MpesaInitiateResult({
    required this.paymentId,
    required this.status,
    this.checkoutRequestId,
  });

  final String paymentId;

  /// "created" | "stk_initiated" | "stk_success" | "stk_failed"
  final String status;

  final String? checkoutRequestId;

  static String _s(Object? v) => (v ?? '').toString().trim();
  static String? _opt(Object? v) {
    final s = _s(v);
    return s.isEmpty ? null : s;
  }

  factory MpesaInitiateResult.fromJson(JsonMap j) {
    final id = _s(j['paymentId'] ?? j['payment_id'] ?? j['id']);
    final status = _s(j['status']);

    if (id.isEmpty) {
      throw const FormatException('MpesaInitiateResult: missing paymentId');
    }
    if (status.isEmpty) {
      throw const FormatException('MpesaInitiateResult: missing status');
    }

    return MpesaInitiateResult(
      paymentId: id,
      status: status,
      checkoutRequestId: _opt(
        j['checkoutRequestId'] ?? j['checkout_request_id'],
      ),
    );
  }
}

class MpesaStatusResponse {
  const MpesaStatusResponse({required this.payment});
  final MpesaPayment payment;

  factory MpesaStatusResponse.fromJson(JsonMap j) =>
      MpesaStatusResponse(payment: MpesaPayment.fromJson(j));
}
