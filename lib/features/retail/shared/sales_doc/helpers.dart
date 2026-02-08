// lib/features/retail/sales/shared/sales_doc/helpers.dart

import 'package:intl/intl.dart';

import 'models.dart';

final DateFormat ymd = DateFormat('yyyy-MM-dd');
final DateFormat docDateFmt = DateFormat.yMMMEd();

final NumberFormat decimal = NumberFormat.decimalPattern();

String formatDocDate(DateTime d) => docDateFmt.format(d);

String money(num amount, String currencyCode) {
  final code = currencyCode.trim().isEmpty ? 'KES' : currencyCode.trim();
  return '$code ${decimal.format(amount)}';
}

String lineDisplayText(SalesDocLineVm li) {
  final title = li.title.trim();
  final subtitle = (li.subtitle ?? '').trim();
  final isPlaceholderTitle = title.toLowerCase() == 'item';

  if ((title.isEmpty || isPlaceholderTitle) && subtitle.isNotEmpty) {
    return subtitle;
  }
  if (subtitle.isEmpty) return title;
  if (title.isEmpty) return subtitle;
  return '$title — $subtitle';
}
