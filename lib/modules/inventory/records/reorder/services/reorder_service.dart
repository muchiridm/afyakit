import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';
import 'package:afyakit/modules/inventory/records/reorder/models/reorder_record.dart';
import 'package:afyakit/modules/inventory/reports/models/stock_report.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class ReorderService {
  final String tenantId;

  ReorderService({required this.tenantId});

  /// 📥 Fetch saved reorder records
  Future<List<ReorderRecord>> fetchReorderRecords() async {
    final snapshot = await db
        .collection('tenants/$tenantId/reorders')
        .orderBy('createdAt', descending: true)
        .get();

    return snapshot.docs.map(ReorderRecord.fromDoc).toList();
  }

  /// 💾 Save a reorder batch with all proposed orders
  Future<void> saveReportOrder(
    List<StockReport> reports, {
    required ItemType type,
    required String exportedByUid,
    required String exportedByName,
    String? note,
  }) async {
    final now = DateTime.now();
    final dateString = DateFormat('yyyyMMdd').format(now);
    final timestamp = Timestamp.fromDate(now);

    // 🆔 Generate next ID
    final baseId = 'PO_$dateString';

    final snapshot = await db
        .collection('tenants/$tenantId/reorders')
        .where(FieldPath.documentId, isGreaterThanOrEqualTo: baseId)
        .get();

    final nextId =
        '$baseId${(snapshot.docs.length + 1).toString().padLeft(3, '0')}';

    // 🔍 Only include SKUs with proposedOrder > 0
    final filtered = reports.where((r) => (r.proposedOrder ?? 0) > 0).toList();

    final items = filtered
        .map(
          (r) => {
            'itemId': r.itemId.split('__').last,
            'itemType': r.itemType.name,
            'quantity': r.proposedOrder!,
          },
        )
        .toList();

    final payload = {
      'createdAt': timestamp,
      'type': type.name,
      'exportedByUid': exportedByUid,
      'exportedByName': exportedByName,
      'itemCount': items.length,
      'items': items,
      if (note != null && note.isNotEmpty) 'note': note,
    };

    await db.collection('tenants/$tenantId/reorders').doc(nextId).set(payload);
  }

  /// ❌ Clear proposedOrder fields from all items
  Future<void> clearProposedOrders() async {
    await Future.wait([
      _clearCollection('medications'),
      _clearCollection('consumables'),
      _clearCollection('equipments'),
    ]);
  }

  Future<void> _clearCollection(String collection) async {
    final collectionRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection(collection);

    final snapshot = await collectionRef.get();
    debugPrint('📦 [$collection] docs to inspect: ${snapshot.docs.length}');

    final batch = db.batch();
    for (final doc in snapshot.docs) {
      final data = doc.data();
      if (!data.containsKey('proposedOrder')) continue;

      debugPrint('🧨 Deleting proposedOrder in $collection → ${doc.id}');
      batch.update(doc.reference, {'proposedOrder': FieldValue.delete()});
    }

    await batch.commit();
    debugPrint('✅ [$collection] batch commit complete');
  }
}
