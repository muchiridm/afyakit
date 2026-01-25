// lib/features/retail/sales/shared/widgets/sales_formatters.dart

import 'package:intl/intl.dart';

final DateFormat ymd = DateFormat('yyyy-MM-dd');
final DateFormat docDateFmt = DateFormat.yMMMEd();

final NumberFormat decimal = NumberFormat.decimalPattern();

String formatDocDate(DateTime d) => docDateFmt.format(d);

String money(num amount, String currencyCode) {
  final code = currencyCode.trim().isEmpty ? 'KES' : currencyCode.trim();
  return '$code ${decimal.format(amount)}';
}
