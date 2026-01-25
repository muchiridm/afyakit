import 'package:flutter/foundation.dart';

@immutable
class PaymentDraft {
  const PaymentDraft({
    required this.amount,
    required this.date,
    this.mode,
    this.referenceNumber,
    this.description,
    this.accountId,
  });

  /// ✅ Convenience: fresh draft defaults
  factory PaymentDraft.today({
    num amount = 0,
    DateTime? now,
    String? mode,
    String? referenceNumber,
    String? description,
    String? accountId,
  }) {
    final n = now ?? DateTime.now();
    return PaymentDraft(
      amount: amount,
      date: DateTime(n.year, n.month, n.day),
      mode: mode,
      referenceNumber: referenceNumber,
      description: description,
      accountId: accountId,
    );
  }

  final num amount;
  final DateTime date;

  /// Zoho payment_mode (Cash, Mpesa, Bank Transfer, etc) depending on your backend/Zoho mapping.
  final String? mode;

  /// Receipt / transaction / mpesa code etc.
  final String? referenceNumber;

  final String? description;

  /// Optional: Zoho account_id to post into (if you support multiple accounts).
  final String? accountId;

  PaymentDraft copyWith({
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
    return PaymentDraft(
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
  PaymentDraft withDateOnly() {
    final d = date;
    return copyWith(date: DateTime(d.year, d.month, d.day));
  }
}
