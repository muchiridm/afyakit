import 'package:flutter/foundation.dart';

@immutable
class SalesDocLineVm {
  const SalesDocLineVm({
    required this.title,
    this.subtitle,
    required this.qty,
    required this.rate,
  });

  final String title;
  final String? subtitle;
  final num qty;
  final num rate;

  num get amount => qty * rate;
}

@immutable
class SalesDocMetaVm {
  const SalesDocMetaVm({
    required this.partyName,
    required this.docNumberOrId,
    required this.status,
    required this.currencyCode,
    required this.total,
    required this.date,

    // ✅ NEW
    this.expiryDate,
  });

  final String partyName;
  final String docNumberOrId;
  final String status;
  final String currencyCode;
  final num total;

  /// Document date (quote date / invoice date)
  final DateTime? date;

  /// ✅ NEW: Quote expiry date (Zoho: expiry_date)
  final DateTime? expiryDate;
}

enum SalesDocMode { view, edit }
