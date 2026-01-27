import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:afyakit/shared/utils/utils.dart';

@immutable
class ZohoPaymentDraft {
  const ZohoPaymentDraft({
    required this.invoiceId,
    required this.amount,
    required this.date,
    this.mode,
    this.referenceNumber,
    this.description,
    this.accountId,
  });

  /// ✅ Convenience: fresh draft defaults
  factory ZohoPaymentDraft.today({
    required String invoiceId,
    num amount = 0,
    DateTime? now,
    String? mode,
    String? referenceNumber,
    String? description,
    String? accountId,
  }) {
    final n = now ?? DateTime.now();
    return ZohoPaymentDraft(
      invoiceId: invoiceId,
      amount: amount,
      date: DateTime(n.year, n.month, n.day),
      mode: mode,
      referenceNumber: referenceNumber,
      description: description,
      accountId: accountId,
    );
  }

  /// ✅ REQUIRED: Zoho invoice_id
  final String invoiceId;

  final num amount;
  final DateTime date;

  /// Zoho payment_mode (Cash, Mpesa, Bank Transfer, etc)
  final String? mode;

  /// Receipt / transaction / mpesa code etc.
  final String? referenceNumber;

  final String? description;

  /// Optional: Zoho account_id to post into
  final String? accountId;

  ZohoPaymentDraft copyWith({
    String? invoiceId,
    num? amount,
    DateTime? date,
    String? mode,
    bool clearMode = false,
    String? referenceNumber,
    bool clearReferenceNumber = false,
    String? description,
    bool clearDescription = false,
    String? accountId,
    bool clearAccountId = false,
  }) {
    return ZohoPaymentDraft(
      invoiceId: (invoiceId ?? this.invoiceId).trim(),
      amount: amount ?? this.amount,
      date: date ?? this.date,
      mode: clearMode ? null : (mode ?? this.mode),
      referenceNumber: clearReferenceNumber
          ? null
          : (referenceNumber ?? this.referenceNumber),
      description: clearDescription ? null : (description ?? this.description),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
    );
  }

  /// ✅ Keep dates consistent (Zoho prefers date-only)
  ZohoPaymentDraft withDateOnly() {
    final d = date;
    return copyWith(date: DateTime(d.year, d.month, d.day));
  }

  // ───────────────────────── Helpers ─────────────────────────

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  static num _safeAmount(num v) {
    if (v.isNaN || v.isInfinite) return 0;
    if (v < 0) return 0;
    return v;
  }

  /// Throwing validator (useful before POST/PUT)
  void assertValid() {
    final inv = invoiceId.trim();
    if (inv.isEmpty) {
      throw ArgumentError('invoiceId is required');
    }

    final amt = _safeAmount(amount);
    if (amt <= 0) {
      throw ArgumentError('amount must be > 0');
    }
  }

  /// ✅ Canonical JSON for your backend `parsePaymentDraft()`.
  ///
  /// Always send canonical keys:
  /// - invoice_id ✅ REQUIRED
  /// - payment_mode
  /// - reference_number
  /// - description
  /// - account_id
  Map<String, Object?> toJson() {
    final d = DateTime(date.year, date.month, date.day);

    final modeClean = readStringOrNull(mode);
    final refClean = readStringOrNull(referenceNumber);
    final descClean = readStringOrNull(description);
    final accountClean = readStringOrNull(accountId);

    return <String, Object?>{
      'invoice_id': invoiceId.trim(),
      'amount': _safeAmount(amount),
      'date': _dateFmt.format(d),
      if (modeClean != null) 'payment_mode': modeClean,
      if (refClean != null) 'reference_number': refClean,
      if (descClean != null) 'description': descClean,
      if (accountClean != null) 'account_id': accountClean,
    };
  }
}
