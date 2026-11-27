// lib/features/retail/payments/mpesa/models/mpesa_payment.dart

import '../../../../shared/utils/utils.dart';

class MpesaPayment {
  const MpesaPayment({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.updatedAt,

    this.purpose,
    this.purposeRef,

    this.zohoSyncStatus,
    this.verificationStatus = 'unverified',
    this.dispatchState,
  });

  /// BE: paymentId
  final String id;

  /// "created" | "stk_initiated" | "stk_success" | "stk_failed"
  final String status;

  final num amount;

  /// BE: always "KES"
  final String currency;

  /// BE: updatedAtIso
  final DateTime updatedAt;

  final String? purpose;
  final String? purposeRef;

  final String? zohoSyncStatus;
  final String verificationStatus;
  final String? dispatchState;

  // ─────────────────────────────
  // Local parsing helpers
  // ─────────────────────────────

  static String _s(Object? v) => (v ?? '').toString().trim();

  static String? _optStr(Object? v) {
    final s = _s(v);
    return s.isEmpty ? null : s;
  }

  static num _n(Object? v) {
    if (v is num) return v;
    final s = _s(v);
    return num.tryParse(s) ?? 0;
  }

  factory MpesaPayment.fromJson(JsonMap j) {
    // Accept { payment: {...} } OR direct payload
    final JsonMap src;
    final p = j['payment'];
    if (isRecord(p)) {
      src = p as JsonMap;
    } else {
      src = j;
    }

    final id = _s(src['paymentId'] ?? src['id'] ?? src['payment_id']);
    final status = _s(src['status']);

    if (id.isEmpty) {
      throw const FormatException('MpesaPayment.fromJson: missing paymentId');
    }
    if (status.isEmpty) {
      throw const FormatException('MpesaPayment.fromJson: missing status');
    }

    final amount = _n(src['amount']);
    final currency = _s(src['currency']);
    if (currency.isEmpty) {
      throw const FormatException('MpesaPayment.fromJson: missing currency');
    }

    final updatedAtIso = _optStr(
      src['updatedAtIso'] ?? src['updated_at_iso'] ?? src['updatedAt'],
    );
    final updatedAt = DateTime.tryParse(updatedAtIso ?? '');
    if (updatedAt == null) {
      throw const FormatException(
        'MpesaPayment.fromJson: missing/invalid updatedAtIso',
      );
    }

    return MpesaPayment(
      id: id,
      status: status,
      amount: amount,
      currency: currency,
      updatedAt: updatedAt,

      purpose: _optStr(src['purpose']),
      purposeRef: _optStr(src['purposeRef'] ?? src['purpose_ref']),

      zohoSyncStatus: _optStr(src['zohoSyncStatus']),
      verificationStatus: _optStr(src['verificationStatus']) ?? 'unverified',
      dispatchState: _optStr(src['dispatchState']),
    );
  }

  /// Pause bounded polling; this is not a declaration of completed payment.
  bool get isTerminal =>
      status == 'stk_success' ||
      status == 'stk_failed' ||
      verificationStatus == 'conflict' ||
      dispatchState == 'uncertain';

  bool get isPaymentComplete =>
      verificationStatus == 'verified' && zohoSyncStatus == 'success';

  String get statusMessage {
    if (verificationStatus == 'conflict') {
      return 'Payment information conflicts; review required. Do not pay again.';
    }
    if (dispatchState == 'uncertain') {
      return 'Payment request outcome uncertain. Do not pay again.';
    }
    if (isPaymentComplete) return 'Payment verified and recorded.';
    if (status == 'stk_success') {
      return 'Provider reported success; payment verification pending.';
    }
    if (status == 'stk_failed') {
      return 'Payment outcome requires confirmation. Do not pay again.';
    }
    return 'Payment pending; check status before paying again.';
  }

  /// Provider-reported success only; never proof of verified funds.
  bool get isSuccess => status == 'stk_success';
  bool get isFailed => status == 'stk_failed';
}
