// lib/features/retail/payments/mpesa/models/mpesa_payment.dart

import '../../../../../shared/utils/utils.dart';

class MpesaPayment {
  const MpesaPayment({
    required this.id,
    required this.status,
    required this.amount,
    required this.currency,
    required this.updatedAt,

    this.purpose,
    this.purposeRef,

    this.mpesaReceiptNumber,
    this.resultCode,
    this.resultDesc,

    this.zohoSyncStatus,
    this.zohoPaymentId,
    this.zohoSyncError,
    this.zohoSyncedAt,
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

  final String? mpesaReceiptNumber;
  final int? resultCode;
  final String? resultDesc;

  final String? zohoSyncStatus;
  final String? zohoPaymentId;
  final String? zohoSyncError;
  final DateTime? zohoSyncedAt;

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

  static int? _i(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    final s = _s(v);
    return int.tryParse(s);
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
    if (updatedAt == null)
      throw const FormatException(
        'MpesaPayment.fromJson: missing/invalid updatedAtIso',
      );

    final zohoSyncedAtIso = _optStr(src['zohoSyncedAtIso']);
    final zohoSyncedAt = zohoSyncedAtIso != null
        ? DateTime.tryParse(zohoSyncedAtIso)
        : null;

    return MpesaPayment(
      id: id,
      status: status,
      amount: amount,
      currency: currency,
      updatedAt: updatedAt,

      purpose: _optStr(src['purpose']),
      purposeRef: _optStr(src['purposeRef'] ?? src['purpose_ref']),

      mpesaReceiptNumber: _optStr(src['mpesaReceiptNumber']),
      resultCode: _i(src['resultCode']),
      resultDesc: _optStr(src['resultDesc']),

      zohoSyncStatus: _optStr(src['zohoSyncStatus']),
      zohoPaymentId: _optStr(src['zohoPaymentId']),
      zohoSyncError: _optStr(src['zohoSyncError']),
      zohoSyncedAt: zohoSyncedAt,
    );
  }

  bool get isTerminal => status == 'stk_success' || status == 'stk_failed';
  bool get isSuccess => status == 'stk_success';
  bool get isFailed => status == 'stk_failed';
}
