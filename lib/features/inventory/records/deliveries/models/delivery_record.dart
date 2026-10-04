// lib/features/inventory/records/deliveries/models/delivery_record.dart

import 'package:afyakit/shared/utils/parse/dates.dart';

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

  const DeliveryRecord({
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
    final deliveryId = (data['deliveryId'] ?? id).toString().trim();

    final sources =
        (data['sources'] as List?)
            ?.map((value) => value.toString().trim())
            .where((value) => value.isNotEmpty)
            .toSet()
            .toList() ??
        const <String>[];

    final rawSnapshots = data['batchSnapshots'];

    final snapshots = rawSnapshots is List
        ? rawSnapshots
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList()
        : <Map<String, dynamic>>[];

    return DeliveryRecord(
      deliveryId: deliveryId,

      date: parseDate(data['date']) ?? DateTime.now(),

      createdAt:
          parseDate(data['createdAt']) ??
          parseDate(data['date']) ??
          DateTime.now(),

      enteredByName: _string(data['enteredByName']) ?? 'Unknown',

      enteredByEmail: _string(data['enteredByEmail']) ?? '',

      sources: sources,

      totalQuantity:
          _int(data['totalQuantity']) ??
          snapshots.fold<int>(
            0,
            (sum, batch) => sum + (_int(batch['quantity']) ?? 0),
          ),

      totalItems: _int(data['totalItems']) ?? snapshots.length,

      batchSnapshots: snapshots,
    );
  }

  /// Number of distinct inventory items represented
  /// across the delivery's batch snapshots.
  int get itemCount {
    return batchSnapshots
        .map((snapshot) => _string(snapshot['itemId']))
        .whereType<String>()
        .toSet()
        .length;
  }

  static String? _string(dynamic value) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    return text.isEmpty ? null : text;
  }

  static int? _int(dynamic value) {
    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(value?.toString() ?? '');
  }
}
