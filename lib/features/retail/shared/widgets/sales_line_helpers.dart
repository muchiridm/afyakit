// lib/features/retail/sales/shared/widgets/sales_line_helpers.dart

import 'sales_doc_models.dart';

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
