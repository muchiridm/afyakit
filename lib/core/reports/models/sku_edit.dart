import 'package:afyakit/core/inventory/extensions/item_type_x.dart';
import 'package:afyakit/core/reports/models/stock_report.dart';

class SkuEdit {
  final ItemType type;
  final String itemId;
  final Map<String, dynamic> fields;

  const SkuEdit({
    required this.type,
    required this.itemId,
    required this.fields,
  });

  /// Apply one key-value update to a StockReport and return a new copy
  StockReport applyTo(StockReport report, String key, dynamic value) {
    switch (key) {
      case 'reorderLevel':
        return report.copyWith(reorderLevel: _toInt(value));
      case 'proposedOrder':
        return report.copyWith(proposedOrder: _toInt(value));
      case 'packSize':
        return report.copyWith(packSize: value.toString());
      case 'package':
        return report.copyWith(package: value.toString());
      default:
        return report; // Unknown field — no-op
    }
  }

  int _toInt(dynamic val) =>
      val is int ? val : int.tryParse(val.toString()) ?? 0;
}
