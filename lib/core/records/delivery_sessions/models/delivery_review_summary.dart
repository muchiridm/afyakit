import 'package:afyakit/core/records/delivery_sessions/models/delivery_record.dart';

class DeliveryReviewSummary {
  final DeliveryRecord summary;
  final List<DeliveryReviewItem> items;

  const DeliveryReviewSummary({required this.summary, required this.items});

  /// 🔍 Total quantity across all items
  int get totalQuantity => summary.totalQuantity;

  /// 🔢 Number of different items (length of items list)
  int get totalItems => summary.totalItems;

  /// 👤 Who entered it — prefers display name + email if both available
  String get enteredBy =>
      '${summary.enteredByName} <${summary.enteredByEmail}>';

  /// 📦 Joined source string
  String get sourceSummary => summary.sources.join(', ');
}

class DeliveryReviewItem {
  final String name;
  final int quantity;
  final String store;
  final String type;

  const DeliveryReviewItem({
    required this.name,
    required this.quantity,
    required this.store,
    required this.type,
  });
}
