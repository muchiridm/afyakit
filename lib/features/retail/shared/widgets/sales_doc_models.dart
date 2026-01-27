// lib/features/retail/sales/shared/widgets/sales_doc_models.dart

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
  });

  final String partyName;
  final String docNumberOrId;
  final String status;
  final String currencyCode;
  final num total;
  final DateTime? date;
}

enum SalesDocMode { view, edit }
