// lib/features/retail/payments/models/zoho_payment_draft.dart

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
    this.reference,
  });

  factory ZohoPaymentDraft.today({
    required String invoiceId,
    num amount = 0,
    DateTime? now,
    String? mode,
    String? description,
    String? accountId,
    String? reference,
  }) {
    final DateTime n = now ?? DateTime.now();

    return ZohoPaymentDraft(
      invoiceId: invoiceId,
      amount: amount,
      date: DateTime(n.year, n.month, n.day),
      mode: mode,
      description: description,
      accountId: accountId,
      reference: reference,
    );
  }

  final String invoiceId;
  final num amount;
  final DateTime date;

  final String? mode;
  final String? description;
  final String? accountId;
  final String? reference;

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
    String? reference,
    bool clearReference = false,
  }) {
    return ZohoPaymentDraft(
      invoiceId: (invoiceId ?? this.invoiceId).trim(),
      amount: amount ?? this.amount,
      date: date ?? this.date,
      mode: clearMode ? null : (mode ?? this.mode),
      description: clearDescription ? null : (description ?? this.description),
      accountId: clearAccountId ? null : (accountId ?? this.accountId),
      reference: clearReference ? null : (reference ?? this.reference),
    );
  }

  ZohoPaymentDraft withDateOnly() {
    final DateTime d = date;
    return copyWith(date: DateTime(d.year, d.month, d.day));
  }

  static final DateFormat _dateFmt = DateFormat('yyyy-MM-dd');

  static num _safeAmount(num value) {
    if (value.isNaN || value.isInfinite) return 0;
    if (value < 0) return 0;
    return value;
  }

  static DateTime _dateOnly(DateTime value) {
    return DateTime(value.year, value.month, value.day);
  }

  void assertValidCreate() {
    final String inv = invoiceId.trim();

    if (inv.isEmpty) {
      throw ArgumentError('invoiceId is required');
    }

    final num amt = _safeAmount(amount);

    if (amt <= 0) {
      throw ArgumentError('amount must be > 0');
    }
  }

  void assertValidUpdate() {
    final num amt = _safeAmount(amount);

    if (amt <= 0) {
      throw ArgumentError('amount must be > 0');
    }
  }

  Map<String, Object?> toCreateJson() {
    final DateTime d = _dateOnly(date);

    final String? modeClean = readStringOrNull(mode);
    final String? descClean = readStringOrNull(description);
    final String? accountClean = readStringOrNull(accountId);
    final String? refClean = readStringOrNull(reference);

    return <String, Object?>{
      'invoice_id': invoiceId.trim(),
      'amount': _safeAmount(amount),
      'date': _dateFmt.format(d),
      if (modeClean != null) 'payment_mode': modeClean,
      if (descClean != null) 'description': descClean,
      if (accountClean != null) 'account_id': accountClean,
      if (refClean != null) 'reference': refClean,
    };
  }

  Map<String, Object?> toUpdateJson() {
    final DateTime d = _dateOnly(date);

    final String? modeClean = readStringOrNull(mode);
    final String? descClean = readStringOrNull(description);
    final String? accountClean = readStringOrNull(accountId);
    final String? refClean = readStringOrNull(reference);

    return <String, Object?>{
      'amount': _safeAmount(amount),
      'date': _dateFmt.format(d),
      if (modeClean != null) 'payment_mode': modeClean,
      if (descClean != null) 'description': descClean,
      if (accountClean != null) 'account_id': accountClean,
      if (refClean != null) 'reference': refClean,
    };
  }
}
