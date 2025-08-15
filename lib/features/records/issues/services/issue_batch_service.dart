// lib/features/issues/services/issue_batch_service.dart

import 'package:afyakit/features/records/delivery_sessions/services/delivery_locked_exception.dart';
import 'package:afyakit/features/records/issues/controllers/controllers/issue_form_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/records/issues/models/enums/issue_type_enum.dart';
import 'package:afyakit/features/records/issues/models/issue_record.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';

import 'package:afyakit/features/records/delivery_sessions/services/delivery_session_service.dart';
import 'package:afyakit/users/providers/current_user_provider.dart';

import 'package:afyakit/shared/services/snack_service.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

class IssueBatchService {
  final String tenantId;
  final Ref ref;

  IssueBatchService({required this.tenantId, required this.ref});

  /// Adjusts batch quantities (issue/transfer/dispense/dispose/transit).
  /// Throws [DeliveryLockedException] if an active delivery session exists for the current user,
  /// unless [enforceDeliveryLock] is false.
  Future<void> adjustBatchQuantity({
    required IssueType type,
    required String fromStore,
    String? toStore,
    required String batchId,
    required String itemId,
    required int quantity,
    required BuildContext context,
    Map<String, dynamic> metadata = const {},
    bool enforceDeliveryLock = true, // ⬅️ NEW
  }) async {
    // ⛔ Guard: block stock mutations while the current user has an open delivery session
    if (enforceDeliveryLock) {
      final user = ref.read(currentUserProvider).asData?.value;
      final email = (user?.email ?? user?.email ?? '').trim().toLowerCase();

      if (email.isNotEmpty) {
        final active = await DeliverySessionService().findOpenSession(
          tenantId: tenantId,
          enteredByEmail: email,
        );

        if (active != null) {
          throw DeliveryLockedException(
            'Stock changes are blocked while delivery ${active.deliveryId} is open for $email.',
          );
        }
      }
    }

    // ─────────────────────────────────────────────────────────────
    // Existing mutation logic
    // ─────────────────────────────────────────────────────────────

    final batchRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection('stores')
        .doc(fromStore)
        .collection('batches')
        .doc(batchId);

    final batchSnap = await batchRef.get();
    if (!batchSnap.exists) throw Exception('❌ Batch not found: $batchId');

    final batch = BatchRecord.fromSnapshot(batchSnap);

    if (batch.quantity < quantity) {
      throw Exception('❌ Insufficient stock in $batchId');
    }

    final newQty = batch.quantity - quantity;
    if (newQty > 0) {
      await batchRef.update({'quantity': newQty});
    } else {
      await batchRef.delete();
    }

    final baseData = {
      'batchId': batchId,
      'itemId': itemId,
      'quantity': quantity,
      'timestamp': FieldValue.serverTimestamp(),
      ...metadata,
    };

    switch (type) {
      case IssueType.transfer:
        final transitRef = db
            .collection('tenants')
            .doc(tenantId)
            .collection('batch_transit')
            .doc();

        await transitRef.set({
          ...baseData,
          'transitId': transitRef.id,
          'issueId': metadata['issueId'],
          'fromStore': fromStore,
          'toStore': toStore,
          'received': false,
          'itemType': batch.itemType.name,
          'expiry': batch.expiryDate?.toIso8601String(),
        });
        break;

      case IssueType.dispense:
        await db
            .collection('tenants')
            .doc(tenantId)
            .collection('batch_dispensations')
            .add({
              ...baseData,
              'storeId': fromStore,
              'reason': metadata['reason'] ?? 'Dispensed',
            });
        break;

      case IssueType.dispose:
        await db
            .collection('tenants')
            .doc(tenantId)
            .collection('batch_disposals')
            .add({
              ...baseData,
              'storeId': fromStore,
              'reason': metadata['reason'] ?? 'Disposed',
            });
        break;
    }
  }

  Future<void> receiveTransit(String docId, Map<String, dynamic> data) async {
    final toStore = data['toStore'];
    final itemId = data['itemId'];
    final quantity = data['quantity'];
    final sourceBatchId = data['batchId'];
    final itemTypeRaw = data['itemType'];
    final expiryString = data['expiry'];

    final transitRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection('batch_transit')
        .doc(docId);

    final storeRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection('stores')
        .doc(toStore);

    final storeDoc = await storeRef.get();

    if (!storeDoc.exists) {
      debugPrint('🏗️ Store [$toStore] not found. Creating...');
      await storeRef.set({
        'storeId': toStore,
        'name': toStore.replaceAll('_', ' ').toUpperCase(),
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('✅ Store [$toStore] created.');
    }

    final newBatchRef = storeRef.collection('batches').doc();

    await newBatchRef.set({
      'batchId': newBatchRef.id,
      'sourceBatchId': sourceBatchId,
      'itemId': itemId,
      'itemType': itemTypeRaw,
      'storeId': toStore,
      'quantity': quantity,
      'expiryDate': expiryString != null
          ? Timestamp.fromDate(DateTime.parse(expiryString))
          : null,
      'receivedDate': FieldValue.serverTimestamp(),
    });

    await transitRef.update({'received': true, 'newBatchId': newBatchRef.id});

    debugPrint('📦 New batch ${newBatchRef.id} created in store [$toStore].');
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getUnreceivedTransitDocs(String issueId) async {
    final snap = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('batch_transit')
        .where('issueId', isEqualTo: issueId)
        .where('received', isEqualTo: false)
        .get();

    return snap.docs;
  }

  Future<void> applyStatusUpdate(
    BuildContext context,
    IssueRecord updated,
    String message,
  ) async {
    try {
      await db
          .collection('tenants')
          .doc(tenantId)
          .collection('issue_records')
          .doc(updated.id)
          .update(updated.toMap());

      SnackService.showSuccess(message);
      await ref.read(issueFormControllerProvider.notifier).loadIssuedRecords();
      if (context.mounted) Navigator.of(context).pop();
    } catch (e) {
      SnackService.showError('❌ $e');
    }
  }
}
