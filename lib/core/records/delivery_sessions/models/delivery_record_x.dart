// lib/features/models/delivery_record_x.dart
import 'package:afyakit/core/records/delivery_sessions/models/delivery_record.dart';

extension DeliveryRecordX on DeliveryRecord {
  /// The first item’s name, if any – otherwise a fallback label.
  String get firstItemName {
    if (batchSnapshots.isEmpty) return 'Delivery';
    final snap = batchSnapshots.first;
    return (snap['itemName'] ??
            snap['name'] ??
            snap['item_type_label'] ??
            'Delivery Item')
        .toString();
  }

  /// Convenience alias (because we stored the ID in `deliveryId`)
  String get id => deliveryId;
}
