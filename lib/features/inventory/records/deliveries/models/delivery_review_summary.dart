// lib/features/inventory/records/deliveries/models/delivery_review_summary.dart

import 'package:afyakit/features/inventory/records/deliveries/models/delivery_record.dart';

class DeliveryReviewSummary {
  final DeliveryRecord summary;
  final List<DeliveryReviewItem> items;

  const DeliveryReviewSummary({required this.summary, required this.items});

  factory DeliveryReviewSummary.fromApi(Map<String, dynamic> data) {
    final session = _map(data['session']);

    final deliveryId =
        _string(session['deliveryId'] ?? data['deliveryId']) ?? '';

    if (deliveryId.isEmpty) {
      throw const FormatException('Delivery review is missing deliveryId');
    }

    final rawBatches = data['batches'];

    final batches = rawBatches is List
        ? rawBatches
              .whereType<Map>()
              .map((value) => Map<String, dynamic>.from(value))
              .toList()
        : <Map<String, dynamic>>[];

    final sources = _stringList(data['sources'] ?? session['sources']);

    final totalQuantity =
        _int(data['totalQuantity']) ??
        batches.fold<int>(
          0,
          (sum, batch) => sum + (_int(batch['quantity']) ?? 0),
        );

    final totalItems = _int(data['totalItems']) ?? batches.length;

    final enteredByName = _string(session['enteredByName']) ?? 'Unknown';

    final enteredByEmail = _string(session['enteredByEmail']) ?? '';

    final summary = DeliveryRecord.fromMap(deliveryId, {
      'deliveryId': deliveryId,

      // Provisional date while the delivery is still open.
      'date': session['startedAt'] ?? DateTime.now().toIso8601String(),

      'createdAt': session['startedAt'],

      'enteredByName': enteredByName,

      'enteredByEmail': enteredByEmail,

      'sources': sources,

      'totalQuantity': totalQuantity,

      'totalItems': totalItems,

      'batchSnapshots': batches,
    });

    final items = batches
        .map(
          (batch) => DeliveryReviewItem(
            batchId: _string(batch['id']) ?? '',
            itemId: _string(batch['itemId']) ?? '',
            name:
                _string(batch['itemName']) ??
                _string(batch['name']) ??
                _string(batch['itemId']) ??
                'Unknown item',
            quantity: _int(batch['quantity']) ?? 0,
            store: _string(batch['storeId'] ?? batch['store']) ?? '',
            type: _string(batch['itemType']) ?? '',
            action: DeliveryReviewAction.fromApi(batch['action']),
          ),
        )
        .toList();

    return DeliveryReviewSummary(summary: summary, items: items);
  }

  int get totalQuantity => summary.totalQuantity;

  int get totalItems => summary.totalItems;

  String get enteredBy {
    final name = summary.enteredByName.trim();

    final email = summary.enteredByEmail.trim();

    if (name.isNotEmpty && email.isNotEmpty) {
      return '$name <$email>';
    }

    if (name.isNotEmpty) {
      return name;
    }

    if (email.isNotEmpty) {
      return email;
    }

    return 'Unknown';
  }

  String get sourceSummary => summary.sources.join(', ');

  static Map<String, dynamic> _map(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return <String, dynamic>{};
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

  static List<String> _stringList(dynamic value) {
    if (value is! List) {
      return const [];
    }

    return value.map(_string).whereType<String>().toSet().toList();
  }
}

enum DeliveryReviewAction {
  created,
  edited;

  static DeliveryReviewAction fromApi(dynamic value) {
    final raw = value?.toString().trim().toLowerCase();

    return raw == 'edited'
        ? DeliveryReviewAction.edited
        : DeliveryReviewAction.created;
  }

  String get label => switch (this) {
    DeliveryReviewAction.created => 'New',
    DeliveryReviewAction.edited => 'Edited',
  };
}

class DeliveryReviewItem {
  final String batchId;
  final String itemId;

  final String name;
  final int quantity;
  final String store;
  final String type;
  final DeliveryReviewAction action;

  const DeliveryReviewItem({
    required this.batchId,
    required this.itemId,
    required this.name,
    required this.quantity,
    required this.store,
    required this.type,
    required this.action,
  });

  bool get isEdited => action == DeliveryReviewAction.edited;

  String get actionLabel => action.label;
}
