// lib/features/retail/shared/models/zoho_payment_draft.dart

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
    this.description,
    this.accountId,
  });

  /// ✅ Convenience: fresh draft defaults
  factory ZohoPaymentDraft.today({
    required String invoiceId,
    num amount = 0,
    DateTime? now,
    String? mode,
    String? description,
    String? accountId,
  }) {
    final n = now ?? DateTime.now();
    return ZohoPaymentDraft(
      invoiceId: invoiceId,
      amount: amount,
      date: DateTime(n.year, n.month, n.day),
      mode: mode,
      description: description,
      accountId: accountId,
    );
  }

  /// ✅ REQUIRED for CREATE: Zoho invoice_id
  final String invoiceId;

  final num amount;
  final DateTime date;

  /// Zoho payment_mode (Cash, Mpesa, Bank Transfer, etc)
  final String? mode;

  final String? description;

  /// Optional: Zoho account_id to post into
  final String? accountId;

  ZohoPaymentDraft copyWith({
    String? invoiceId,
    num? amount,
    DateTime? date,
    String? mode,
    bool clearMode = false,
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
      description: clearDescription ? null : (description ?? this.description),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
    );
  }

  /// ✅ Keep dates consistent (Zoho prefers date-only)
  ZohoPaymentDraft withDateOnly() {
    final d = date;
    return copyWith(date: DateTime(d.year, d.month, d.day));
  }

  // ───────────────────────── Normalizers ─────────────────────────

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  static num _safeAmount(num v) {
    if (v.isNaN || v.isInfinite) return 0;
    if (v < 0) return 0;
    return v;
  }

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  // ───────────────────────── Validators ─────────────────────────

  /// Throwing validator (useful before POST)
  void assertValidCreate() {
    final inv = invoiceId.trim();
    if (inv.isEmpty) throw ArgumentError('invoiceId is required');

    final amt = _safeAmount(amount);
    if (amt <= 0) throw ArgumentError('amount must be > 0');
  }

  /// Throwing validator (useful before PUT)
  void assertValidUpdate() {
    final amt = _safeAmount(amount);
    if (amt <= 0) throw ArgumentError('amount must be > 0');
  }

  // ───────────────────────── JSON ─────────────────────────
  // Always send canonical keys expected by backend:
  // - invoice_id (create only)
  // - payment_mode
  // - description
  // - account_id
  // ───────────────────────────────────────────────────────

  Map<String, Object?> toCreateJson() {
    final d = _dateOnly(date);

    final modeClean = readStringOrNull(mode);
    final descClean = readStringOrNull(description);
    final accountClean = readStringOrNull(accountId);

    return <String, Object?>{
      'invoice_id': invoiceId.trim(),
      'amount': _safeAmount(amount),
      'date': _dateFmt.format(d),
      if (modeClean != null) 'payment_mode': modeClean,
      if (descClean != null) 'description': descClean,
      if (accountClean != null) 'account_id': accountClean,
    };
  }

  Map<String, Object?> toUpdateJson() {
    final d = _dateOnly(date);

    final modeClean = readStringOrNull(mode);
    final descClean = readStringOrNull(description);
    final accountClean = readStringOrNull(accountId);

    return <String, Object?>{
      'amount': _safeAmount(amount),
      'date': _dateFmt.format(d),
      if (modeClean != null) 'payment_mode': modeClean,
      if (descClean != null) 'description': descClean,
      if (accountClean != null) 'account_id': accountClean,
    };
  }
}
