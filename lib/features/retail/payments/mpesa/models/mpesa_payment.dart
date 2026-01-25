import '../../../../../shared/utils/utils.dart';

class MpesaPayment {
  const MpesaPayment({
    required this.id,
    required this.status,
    required this.amount,
    this.phone,
    this.purpose,
    this.purposeRef,
    this.mpesaReceiptNumber,
    this.checkoutRequestId,
    this.merchantRequestId,
    this.transactionDateRaw,
    this.createdAt,
    this.updatedAt,
    this.zohoSyncStatus,
    this.zohoPaymentId,
    this.zohoSyncError,
  });

  final String id;

  /// e.g. "stk_pending" | "stk_success" | "stk_failed"
  final String status;

  final num amount;

  final String? phone;
  final String? purpose;
  final String? purposeRef;

  final String? mpesaReceiptNumber;
  final String? checkoutRequestId;
  final String? merchantRequestId;

  /// Daraja YYYYMMDDHHMMSS (often)
  final String? transactionDateRaw;

  final DateTime? createdAt;
  final DateTime? updatedAt;

  /// "idle" | "syncing" | "success" | "failed"
  final String? zohoSyncStatus;
  final String? zohoPaymentId;
  final String? zohoSyncError;

  // ─────────────────────────────
  // Local parsing helpers (NO deps)
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

  static DateTime? _dt(Object? v) {
    if (v is DateTime) return v;
    final s = _s(v);
    if (s.isEmpty) return null;

    // Accept ISO strings
    final iso = DateTime.tryParse(s);
    if (iso != null) return iso;

    // Accept Firestore Timestamp-ish maps if they sneak in:
    // { _seconds: 123, _nanoseconds: 0 } or { seconds: 123, nanoseconds: 0 }
    if (v is Map) {
      final sec = v['_seconds'] ?? v['seconds'];
      final ns = v['_nanoseconds'] ?? v['nanoseconds'];
      if (sec is int) {
        final ms = sec * 1000 + ((ns is int) ? (ns ~/ 1000000) : 0);
        return DateTime.fromMillisecondsSinceEpoch(ms, isUtc: true);
      }
    }

    return null;
  }

  factory MpesaPayment.fromJson(JsonMap j) {
    // allow either {payment:{...}} or direct payload
    final JsonMap src;
    final p = j['payment'];
    if (isRecord(p)) {
      src = p as JsonMap;
    } else {
      src = j;
    }

    final id = _s(src['id'] ?? src['paymentId'] ?? src['payment_id']);
    final status = _s(src['status']);
    if (id.isEmpty) {
      throw const FormatException('MpesaPayment.fromJson: missing id');
    }
    if (status.isEmpty) {
      throw const FormatException('MpesaPayment.fromJson: missing status');
    }

    return MpesaPayment(
      id: id,
      status: status,
      amount: _n(src['amount']),
      phone: _optStr(src['phone']),
      purpose: _optStr(src['purpose']),
      purposeRef: _optStr(src['purposeRef'] ?? src['purpose_ref']),
      mpesaReceiptNumber: _optStr(
        src['mpesaReceiptNumber'] ?? src['mpesa_receipt_number'],
      ),
      checkoutRequestId: _optStr(
        src['checkoutRequestId'] ?? src['checkout_request_id'],
      ),
      merchantRequestId: _optStr(
        src['merchantRequestId'] ?? src['merchant_request_id'],
      ),
      transactionDateRaw: _optStr(
        src['transactionDate'] ?? src['transaction_date'],
      ),
      createdAt: _dt(src['createdAt'] ?? src['created_at']),
      updatedAt: _dt(src['updatedAt'] ?? src['updated_at']),
      zohoSyncStatus: _optStr(src['zohoSyncStatus'] ?? src['zoho_sync_status']),
      zohoPaymentId: _optStr(src['zohoPaymentId'] ?? src['zoho_payment_id']),
      zohoSyncError: _optStr(src['zohoSyncError'] ?? src['zoho_sync_error']),
    );
  }
}
