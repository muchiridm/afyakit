import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afyakit/features/inventory/models/item_type_enum.dart';
import 'package:afyakit/shared/utils/parsers/parse_date.dart';
import 'package:afyakit/shared/utils/parsers/parse_item_type.dart';
import 'package:flutter/foundation.dart';

class BatchRecord {
  final String id;
  final String? fullPath;

  final String itemId;
  final ItemType itemType;
  final String storeId;

  final DateTime? expiryDate;
  final DateTime? receivedDate;
  final int quantity;

  final String? deliveryId;

  final String? enteredByUid;
  final String? enteredByName;
  final String? enteredByEmail;

  final String? source;

  final bool isEdited;
  final String? editReason;

  const BatchRecord({
    required this.id,
    this.fullPath,
    required this.itemId,
    required this.itemType,
    required this.storeId,
    this.expiryDate,
    this.receivedDate,
    required this.quantity,
    this.deliveryId,
    this.enteredByUid,
    this.enteredByName,
    this.enteredByEmail,
    this.source,
    this.isEdited = false,
    this.editReason,
  });

  // ─────────────────────────────────────────────
  // 🔥 From Firestore
  factory BatchRecord.fromSnapshot(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final itemId = data['itemId'];

    if (itemId == null || itemId is! String || itemId.isEmpty) {
      throw StateError(
        '❌ Missing or invalid `itemId` in batch: ${doc.reference.path}',
      );
    }

    final extractedStoreId = _extractStoreId(doc.reference.path);
    final embeddedStoreId = data['storeId'];
    if (embeddedStoreId != null && embeddedStoreId != extractedStoreId) {
      debugPrint(
        '⚠️ Mismatch: embedded storeId ($embeddedStoreId) ≠ path storeId ($extractedStoreId)',
      );
    }

    return BatchRecord(
      id: doc.id,
      fullPath: doc.reference.path,
      itemId: itemId,
      itemType: parseItemType(data['itemType']),
      storeId: extractedStoreId,
      expiryDate: parseDate(data['expiryDate']),
      receivedDate: parseDate(data['receivedDate']),
      quantity: data['quantity'] ?? 0,
      deliveryId: data['deliveryId'],
      enteredByUid: data['enteredByUid'],
      enteredByName: data['enteredByName'],
      enteredByEmail: data['enteredByEmail'],
      source: data['source'],
      isEdited: data['isEdited'] ?? false,
      editReason: data['editReason'],
    );
  }

  static String _extractStoreId(String path) {
    final match = RegExp(r'stores/([^/]+)/batches').firstMatch(path);
    return match?.group(1) ?? '';
  }

  // ─────────────────────────────────────────────
  // 🧬 CopyWith
  BatchRecord copyWith({
    String? id,
    String? fullPath,
    String? itemId,
    ItemType? itemType,
    String? storeId,
    DateTime? expiryDate,
    DateTime? receivedDate,
    int? quantity,
    String? deliveryId,
    String? enteredByUid,
    String? enteredByName,
    String? enteredByEmail,
    String? source,
    bool? isEdited,
    String? editReason,
  }) {
    return BatchRecord(
      id: id ?? this.id,
      fullPath: fullPath ?? this.fullPath,
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
      storeId: storeId ?? this.storeId,
      expiryDate: expiryDate ?? this.expiryDate,
      receivedDate: receivedDate ?? this.receivedDate,
      quantity: quantity ?? this.quantity,
      deliveryId: deliveryId ?? this.deliveryId,
      enteredByUid: enteredByUid ?? this.enteredByUid,
      enteredByName: enteredByName ?? this.enteredByName,
      enteredByEmail: enteredByEmail ?? this.enteredByEmail,
      source: source ?? this.source,
      isEdited: isEdited ?? this.isEdited,
      editReason: editReason ?? this.editReason,
    );
  }

  // 🔁 From API JSON
  factory BatchRecord.fromJson(String id, Map<String, dynamic> json) {
    return BatchRecord(
      id: id,
      itemId: json['itemId'] ?? '',
      itemType: parseItemType(json['itemType']),
      storeId: json['storeId'] ?? '',
      expiryDate: parseDate(json['expiryDate']),
      receivedDate: parseDate(json['receivedDate']),
      quantity: json['quantity'] ?? 0,
      deliveryId: json['deliveryId'],
      enteredByUid: json['enteredByUid'],
      enteredByName: json['enteredByName'],
      enteredByEmail: json['enteredByEmail'],
      source: json['source'],
      isEdited: json['isEdited'] ?? false,
      editReason: json['editReason'],
    );
  }

  // 📄 From embedded maps (e.g. delivery snapshot)
  factory BatchRecord.fromMap(Map<String, dynamic> map) {
    return BatchRecord(
      id: map['id'] ?? '',
      itemId: map['itemId'] ?? '',
      itemType: parseItemType(map['itemType']),
      storeId: map['storeId'] ?? '',
      expiryDate: parseDate(map['expiryDate']),
      receivedDate: parseDate(map['receivedDate']),
      quantity: map['quantity'] ?? 0,
      deliveryId: map['deliveryId'],
      enteredByUid: map['enteredByUid'],
      enteredByName: map['enteredByName'],
      enteredByEmail: map['enteredByEmail'],
      source: map['source'],
      isEdited: map['isEdited'] ?? false,
      editReason: map['editReason'],
    );
  }

  // 📤 Firestore / API serialization
  Map<String, dynamic> toMap({bool forFirestore = true}) => {
    'itemId': itemId,
    'itemType': itemType.name,
    'storeId': storeId,
    'expiryDate': serializeDate(expiryDate, forFirestore: forFirestore),
    'receivedDate': serializeDate(receivedDate, forFirestore: forFirestore),
    'quantity': quantity,
    'deliveryId': deliveryId,
    'enteredByUid': enteredByUid,
    'enteredByName': enteredByName,
    'enteredByEmail': enteredByEmail,
    'source': source,
    'isEdited': isEdited,
    'editReason': editReason,
  };

  Map<String, dynamic> toJson() {
    final map = toMap(forFirestore: false);
    for (final entry in map.entries) {
      if (entry.value is Timestamp) {
        debugPrint('🚨 toJson leaked Timestamp: ${entry.key} → ${entry.value}');
      }
    }
    return map;
  }

  Map<String, dynamic> toRawMap() => {'id': id, ...toMap(forFirestore: false)};

  // 🧱 Blank stub for editors
  factory BatchRecord.blank({
    required String itemId,
    required ItemType itemType,
  }) {
    return BatchRecord(
      id: '',
      fullPath: null,
      itemId: itemId,
      itemType: itemType,
      storeId: '',
      expiryDate: null,
      receivedDate: null,
      quantity: 0,
      deliveryId: null,
      enteredByUid: null,
      enteredByName: null,
      enteredByEmail: null,
      source: null,
      isEdited: false,
      editReason: null,
    );
  }
}
