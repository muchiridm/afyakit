import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/parsers/parse_date.dart';

class DeliveryRecord {
  final String deliveryId;
  final DateTime date;
  final DateTime createdAt;
  final String enteredByName;
  final String enteredByEmail;
  final List<String> sources;
  final int totalQuantity;
  final int totalItems;
  final List<Map<String, dynamic>> batchSnapshots;

  DeliveryRecord({
    required this.deliveryId,
    required this.date,
    required this.createdAt,
    required this.enteredByName,
    required this.enteredByEmail,
    required this.sources,
    required this.totalQuantity,
    required this.totalItems,
    required this.batchSnapshots,
  });

  factory DeliveryRecord.fromMap(String id, Map<String, dynamic> data) {
    return DeliveryRecord(
      deliveryId: id,
      date: parseDate(data['date']) ?? DateTime.now(),
      createdAt: parseDate(data['createdAt']) ?? DateTime.now(),
      enteredByName: data['enteredByName'] ?? 'unknown',
      enteredByEmail: data['enteredByEmail'] ?? 'unknown',
      sources:
          (data['sources'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          ['unknown'],
      totalQuantity: data['totalQuantity'] ?? 0,
      totalItems: data['totalItems'] ?? 0,
      batchSnapshots:
          (data['batchSnapshots'] as List<dynamic>?)
              ?.map((e) => Map<String, dynamic>.from(e))
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date.toIso8601String(),
    'createdAt': createdAt.toIso8601String(),
    'enteredByName': enteredByName,
    'enteredByEmail': enteredByEmail,
    'sources': sources,
    'totalQuantity': totalQuantity,
    'totalItems': totalItems,
    'batchSnapshots': batchSnapshots,
  };

  /// 🏗️ Create from a list of BatchRecords and classify each as 'created' or 'edited'
  factory DeliveryRecord.fromBatches(
    List<BatchRecord> batches,
    String deliveryId, {
    required String enteredByName,
    required String enteredByEmail,
    required List<String> sources,
  }) {
    if (batches.isEmpty) {
      throw ArgumentError(
        'Cannot create DeliveryRecord from empty batch list.',
      );
    }

    final now = DateTime.now();
    final totalQty = batches.fold<int>(0, (sum, b) => sum + b.quantity);

    final snapshots = batches.map((batch) {
      final map = batch.toMap();
      map['action'] = batch.isEdited == true
          ? 'edited'
          : 'created'; // 👈 Add action flag
      return map;
    }).toList();

    return DeliveryRecord(
      deliveryId: deliveryId,
      date: now,
      createdAt: now,
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      sources: sources,
      totalQuantity: totalQty,
      totalItems: batches.length,
      batchSnapshots: snapshots,
    );
  }

  // 🧮 Distinct item count, used in UI display
  int get itemCount {
    final ids = batchSnapshots
        .map((s) => s['itemId']?.toString())
        .where((id) => id != null && id.isNotEmpty)
        .toSet();
    return ids.length;
  }
}
