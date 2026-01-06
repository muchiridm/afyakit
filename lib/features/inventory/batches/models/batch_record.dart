import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:afyakit/features/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/shared/utils/parsers/parse_date.dart';
import 'package:afyakit/shared/utils/parsers/parse_item_type.dart';
import 'package:flutter/foundation.dart';

@immutable
class BatchRecord {
  final String id;
  final String? fullPath;

  // Tenant / store (present on doc and derivable from path)
  final String tenantId;
  final String storeId;

  final String itemId;
  final ItemType itemType;

  final DateTime? expiryDate;
  final DateTime? receivedDate;
  final int quantity;

  // 🔗 Delivery linkage
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
    required this.tenantId,
    required this.storeId,
    required this.itemId,
    required this.itemType,
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
  factory BatchRecord.fromSnapshot(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data() ?? const <String, dynamic>{};
    final path = doc.reference.path;
    return _fromData(
      id: doc.id,
      data: data,
      // only from snapshot we know the path, so we can warn on mismatches
      path: path,
    );
  }

  // 🔁 From API JSON
  factory BatchRecord.fromJson(String id, Map<String, dynamic> json) {
    return _fromData(id: id, data: json);
  }

  // 📄 From embedded maps
  factory BatchRecord.fromMap(Map<String, dynamic> map) {
    return _fromData(id: (map['id'] as String?) ?? '', data: map);
  }

  // ─────────────────────────────────────────────
  // 📤 Serialization
  Map<String, dynamic> toMap({bool forFirestore = true}) {
    final map = <String, dynamic>{
      'tenantId': tenantId,
      'storeId': storeId,
      'itemId': itemId,
      'itemType': itemType.name,
      'expiryDate': serializeDate(expiryDate, forFirestore: forFirestore),
      'receivedDate': serializeDate(receivedDate, forFirestore: forFirestore),
      'quantity': quantity,
      'deliveryId': deliveryId, // canonical
      'enteredByUid': enteredByUid,
      'enteredByName': enteredByName,
      'enteredByEmail': enteredByEmail,
      'source': source,
      'isEdited': isEdited,
      'editReason': editReason,
    };

    // ✅ Back-compat: dual-write for readers expecting snake_case
    map['delivery_id'] = deliveryId;

    return map;
  }

  Map<String, dynamic> toJson() {
    // for API payloads; same content as toMap(false) + the snake key
    final map = toMap(forFirestore: false);
    map['delivery_id'] = deliveryId; // ensure API gets both variants
    // sanity: never leak Timestamp to the API
    for (final e in map.entries) {
      if (e.value is Timestamp) {
        debugPrint('🚨 toJson leaked Timestamp: ${e.key} → ${e.value}');
      }
    }
    return map;
  }

  Map<String, dynamic> toRawMap() => {'id': id, ...toMap(forFirestore: false)};

  // 🧬 CopyWith
  BatchRecord copyWith({
    String? id,
    String? fullPath,
    String? tenantId,
    String? storeId,
    String? itemId,
    ItemType? itemType,
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
      tenantId: tenantId ?? this.tenantId,
      storeId: storeId ?? this.storeId,
      itemId: itemId ?? this.itemId,
      itemType: itemType ?? this.itemType,
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

  // 🧱 Blank stub for editors
  factory BatchRecord.blank({
    required String itemId,
    required ItemType itemType,
    required String tenantId,
    required String storeId,
  }) {
    return BatchRecord(
      id: '',
      fullPath: null,
      tenantId: tenantId,
      storeId: storeId,
      itemId: itemId,
      itemType: itemType,
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

  // ─────────────────────────────────────────────
  // Internals: DRY parsing helpers & core builder
  static final RegExp _tenantRe = RegExp(r'tenants/([^/]+)/stores/');
  static final RegExp _storeRe = RegExp(r'stores/([^/]+)/batches');

  static String _extractTenantId(String path) =>
      _tenantRe.firstMatch(path)?.group(1) ?? '';

  static String _extractStoreId(String path) =>
      _storeRe.firstMatch(path)?.group(1) ?? '';

  static String? _trimmed(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static String? _pickS(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = _trimmed(m[k]);
      if (v != null) return v;
    }
    return null;
  }

  static int _toInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(_trimmed(v) ?? '') ?? 0;
  }

  static DateTime? _toDate(dynamic v) {
    // delegate to your parser; it already handles String/Timestamp/null
    return parseDate(v);
  }

  // lib/features/batches/models/batch_record.dart
  // only the _fromData changes shown

  static BatchRecord _fromData({
    required String id,
    required Map<String, dynamic> data,
    String? path,
  }) {
    // accept both camel/snake and backend's "store"
    final embeddedTenantId = _pickS(data, const ['tenantId', 'tenant_id']);
    final embeddedStoreId = _pickS(data, const [
      'storeId',
      'store_id',
      'store',
    ]); // 👈 add "store"

    String tenantId = embeddedTenantId ?? '';
    String storeId = embeddedStoreId ?? '';

    if ((tenantId.isEmpty || storeId.isEmpty) && path != null) {
      final pathTenantId = _extractTenantId(path);
      final pathStoreId = _extractStoreId(path);
      tenantId = tenantId.isEmpty ? pathTenantId : tenantId;
      storeId = storeId.isEmpty ? pathStoreId : storeId;

      if (embeddedTenantId != null && embeddedTenantId != pathTenantId) {
        debugPrint(
          '⚠️ tenantId mismatch: embedded=$embeddedTenantId path=$pathTenantId ($path)',
        );
      }
      if (embeddedStoreId != null && embeddedStoreId != pathStoreId) {
        debugPrint(
          '⚠️ storeId mismatch: embedded=$embeddedStoreId path=$pathStoreId ($path)',
        );
      }
    }

    final itemId = _pickS(data, const ['itemId', 'item_id']) ?? '';
    if (itemId.isEmpty) {
      throw StateError(
        '❌ Missing or invalid `itemId` in batch: ${path ?? '(no path)'}',
      );
    }

    final itemTypeRaw = data['itemType'] ?? data['item_type'];

    return BatchRecord(
      id: id,
      fullPath: path,
      tenantId: tenantId,
      storeId: storeId,
      itemId: itemId,
      itemType: parseItemType(itemTypeRaw),
      expiryDate: _toDate(data['expiryDate'] ?? data['expiry_date']),
      receivedDate: _toDate(data['receivedDate'] ?? data['received_date']),
      quantity: _toInt(data['quantity']),
      deliveryId: _pickS(data, const ['deliveryId', 'delivery_id']),
      enteredByUid: _pickS(data, const ['enteredByUid', 'entered_by_uid']),
      enteredByName: _pickS(data, const ['enteredByName', 'entered_by_name']),
      enteredByEmail: _pickS(data, const [
        'enteredByEmail',
        'entered_by_email',
      ]),
      source: _trimmed(data['source']),
      isEdited:
          (data['isEdited'] as bool?) ?? (data['is_edited'] as bool?) ?? false,
      editReason: _pickS(data, const ['editReason', 'edit_reason']),
    );
  }
}
