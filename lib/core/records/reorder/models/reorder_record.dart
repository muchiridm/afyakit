import 'package:afyakit/core/inventory/models/item_type_enum.dart';
import 'package:afyakit/core/records/reorder/models/reorder_item.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class ReorderRecord {
  final String id;
  final DateTime createdAt;
  final String exportedByUid;
  final String exportedByName;
  final ItemType type;
  final int itemCount;
  final List<ReorderItem> items;
  final String? note;

  ReorderRecord({
    required this.id,
    required this.createdAt,
    required this.exportedByUid,
    required this.exportedByName,
    required this.type,
    required this.itemCount,
    required this.items,
    this.note,
  });

  factory ReorderRecord.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    final items = (data['items'] as List<dynamic>? ?? [])
        .map((e) => ReorderItem.fromMap(e as Map<String, dynamic>))
        .toList();

    return ReorderRecord(
      id: doc.id,
      createdAt: (data['createdAt'] as Timestamp).toDate(),
      exportedByUid: data['exportedByUid'] as String,
      exportedByName: data['exportedByName'] as String,
      type: ItemType.fromString(data['type'] as String),
      itemCount: data['itemCount'] as int,
      items: items,
      note: data['note'] as String?,
    );
  }

  /// Optional: label for UI
  String get itemTypeLabel => type.label;
}
