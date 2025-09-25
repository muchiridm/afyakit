import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart'; // db
import 'package:afyakit/shared/services/snack_service.dart';

import 'package:afyakit/core/records/issues/extensions/issue_type_x.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/models/issue_resume_progress.dart';
import 'package:afyakit/core/records/issues/controllers/form/issue_form_controller.dart';

import 'package:afyakit/core/records/issues/services/stock_repo.dart';
import 'package:afyakit/core/records/issues/services/transfer_service.dart';

import 'package:afyakit/core/records/deliveries/controllers/delivery_session_engine.dart';
import 'package:afyakit/core/records/deliveries/utils/delivery_locked_exception.dart';

class IssueBatchService {
  final String tenantId;
  final Ref ref;

  late final StockRepo _repo = StockRepo(tenantId);
  late final TransferService _transfer = TransferService(_repo);

  IssueBatchService({required this.tenantId, required this.ref});

  // ─────────────────────────────────────────────────────────────
  // Public API
  // ─────────────────────────────────────────────────────────────

  Future<void> adjustBatchQuantity({
    required IssueType type,
    required String fromStore,
    String? toStore,
    required String batchId,
    required String itemId,
    required int quantity,
    required BuildContext context,
    Map<String, dynamic> metadata = const {},
    bool enforceDeliveryLock = true,
  }) async {
    await _guardDeliveryLock(enforceDeliveryLock);
    if (quantity <= 0) throw StateError('❌ Quantity must be positive.');

    switch (type) {
      case IssueType.transfer:
        final dest = (toStore ?? '').trim();
        if (dest.isEmpty) {
          throw StateError('❌ Destination store is required for transfers.');
        }

        final meta = {...metadata};
        final issueId = (meta['issueId'] ?? '').toString();
        final entryId = (meta['entryId'] ?? '').toString();
        if (issueId.isNotEmpty && entryId.isNotEmpty) {
          meta['transitId'] = 'transit_${issueId}_$entryId';
        }

        await _transfer.transfer(
          fromStore: fromStore,
          toStore: dest,
          sourceBatchId: batchId,
          itemId: itemId,
          quantity: quantity,
          metadata: meta,
        );
        break;

      case IssueType.dispense:
        await _dispenseNow(
          storeId: fromStore,
          itemId: itemId,
          batchId: batchId,
          quantity: quantity,
          reason: (metadata['reason'] ?? 'Dispensed').toString(),
          extra: metadata,
        );
        break;

      case IssueType.dispose:
        await _disposeNow(
          storeId: fromStore,
          itemId: itemId,
          batchId: batchId,
          quantity: quantity,
          reason: (metadata['reason'] ?? 'Disposed').toString(),
          extra: metadata,
        );
        break;
    }
  }

  /// Create destination batch + mark transit received (atomic).
  Future<void> receiveTransit(String docId, Map<String, dynamic> data) async {
    await db.runTransaction((tx) async {
      final transitRef = _repo.transitDoc(docId);
      final transitSnap = await tx.get(transitRef);
      if (!transitSnap.exists) {
        throw StateError('❌ Transit doc not found: $docId');
      }

      final t = transitSnap.data()!;
      if ((t['received'] as bool?) == true) {
        return; // already received → no-op
      }

      final toStore = StockRepo.asString(t['toStore'] ?? data['toStore']);
      final itemId = StockRepo.asString(t['itemId'] ?? data['itemId']);
      final qty = StockRepo.asInt(t['quantity'] ?? data['quantity']);
      final srcBatch = StockRepo.asString(t['batchId'] ?? data['batchId']);
      final itemType = StockRepo.asString(t['itemType'] ?? data['itemType']);
      final expiry = StockRepo.asString(t['expiry'] ?? data['expiry']);

      if (toStore.isEmpty || itemId.isEmpty || qty <= 0) {
        throw StateError('❌ Invalid transit payload for $docId');
      }

      // Ensure destination store exists
      final storeRef = _repo.storeDoc(toStore);
      final storeSnap = await tx.get(storeRef);
      if (!storeSnap.exists) {
        tx.set(storeRef, {
          'storeId': toStore,
          'name': toStore.replaceAll('_', ' ').toUpperCase(),
          'createdAt': FieldValue.serverTimestamp(),
        });
      }

      // Create destination batch
      final newBatchRef = _repo.batchesCol(toStore).doc();
      tx.set(newBatchRef, {
        'tenantId': tenantId,
        'storeId': toStore,
        'itemId': itemId,
        'itemType': itemType,
        'quantity': qty,
        'receivedDate': FieldValue.serverTimestamp(),
        'expiryDate': expiry.isNotEmpty
            ? Timestamp.fromDate(DateTime.parse(expiry))
            : null,
        'sourceBatchId': srcBatch,
        'source': 'transfer',
        'deliveryId': null,
        'isEdited': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Mark transit received
      tx.update(transitRef, {
        'received': true,
        'newBatchId': newBatchRef.id,
        'receivedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>>
  getUnreceivedTransitDocs(String issueId) async {
    final snap = await _repo
        .transitCol()
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
      await _repo.issuesCol().doc(updated.id).update(updated.toMap());
      SnackService.showSuccess(message);
      await ref.read(issueFormControllerProvider.notifier).loadIssuedRecords();
      if (context.mounted) Navigator.of(context).pop();
    } on FirebaseException catch (e, st) {
      debugPrint(
        '💥 [applyStatusUpdate] FirebaseException code=${e.code} msg=${e.message}\n$st',
      );
      SnackService.showError('❌ ${e.message ?? 'Update failed'}');
      throw Exception('applyStatusUpdate failed (${e.code}): ${e.message}');
    } catch (e, st) {
      debugPrint('💥 [applyStatusUpdate] Unexpected: $e\n$st');
      SnackService.showError('❌ $e');
      rethrow;
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Bulk helpers (resume & receive-all)
  // ─────────────────────────────────────────────────────────────

  Future<IssueResumeProgress> resumeIssueIssuance(
    IssueRecord issue, {
    bool enforceDeliveryLock = true,
  }) async {
    await _guardDeliveryLock(enforceDeliveryLock);

    final total = issue.entries.length;
    var processed = 0, missing = 0, insufficient = 0, other = 0;

    final fromStoreName =
        await _repo.readStoreName(issue.fromStore) ?? issue.fromStore;

    for (final e in issue.entries) {
      try {
        final batchId = (e.batchId ?? '').trim();
        if (batchId.isEmpty) {
          missing++;
          debugPrint('↯ [resumeIssueIssuance] entry=${e.id} → missing batchId');
          continue;
        }

        final meta = <String, dynamic>{
          'issueId': issue.id,
          'entryId': e.id,
          'itemType': e.itemType.key,
          'fromStoreName': fromStoreName,
          'source': 'transfer',
          'transitId': 'transit_${issue.id}_${e.id}', // deterministic
        };

        await _transfer.transfer(
          fromStore: issue.fromStore,
          toStore: issue.toStore,
          sourceBatchId: batchId,
          itemId: e.itemId,
          quantity: e.quantity,
          metadata: meta,
        );

        processed++;
      } on StateError catch (err) {
        final msg = err.toString();
        if (msg.contains('Source batch not found')) {
          missing++;
        } else if (msg.contains('Insufficient stock')) {
          insufficient++;
        } else {
          other++;
        }
        debugPrint('↯ [resumeIssueIssuance] entry=${e.id} → $msg');
      } catch (err, st) {
        other++;
        debugPrint('↯ [resumeIssueIssuance] entry=${e.id} → $err\n$st');
      }
    }

    final prog = IssueResumeProgress(
      total: total,
      processed: processed,
      missingBatch: missing,
      insufficient: insufficient,
      otherErrors: other,
    );
    return prog;
  }

  Future<int> receiveAllUnreceivedTransits(String issueId) async {
    final docs = await getUnreceivedTransitDocs(issueId);
    var received = 0;
    for (final d in docs) {
      try {
        await receiveTransit(d.id, d.data());
        received++;
      } catch (e, st) {
        debugPrint('↯ [receiveAllUnreceivedTransits] ${d.id} → $e\n$st');
      }
    }
    return received;
  }

  // ─────────────────────────────────────────────────────────────
  // Smaller mutations
  // ─────────────────────────────────────────────────────────────

  Future<void> _dispenseNow({
    required String storeId,
    required String itemId,
    required String batchId,
    required int quantity,
    required String reason,
    required Map<String, dynamic> extra,
  }) async {
    final pathHint = 'store=$storeId batch=$batchId';
    try {
      await _repo.decrementOrDelete(
        storeId: storeId,
        batchId: batchId,
        amount: quantity,
      );
      await _repo.dispensationsCol().add({
        'tenantId': tenantId,
        'storeId': storeId,
        'itemId': itemId,
        'quantity': quantity,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (e, st) {
      debugPrint('💥 [_dispenseNow] $pathHint → $e\n$st');
      throw StateError('Failed to dispense [$pathHint]: $e');
    }
  }

  Future<void> _disposeNow({
    required String storeId,
    required String itemId,
    required String batchId,
    required int quantity,
    required String reason,
    required Map<String, dynamic> extra,
  }) async {
    final pathHint = 'store=$storeId batch=$batchId';
    try {
      await _repo.decrementOrDelete(
        storeId: storeId,
        batchId: batchId,
        amount: quantity,
      );
      await _repo.disposalsCol().add({
        'tenantId': tenantId,
        'storeId': storeId,
        'itemId': itemId,
        'quantity': quantity,
        'reason': reason,
        'timestamp': FieldValue.serverTimestamp(),
        ...extra,
      });
    } catch (e, st) {
      debugPrint('💥 [_disposeNow] $pathHint → $e\n$st');
      throw StateError('Failed to dispose [$pathHint]: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // Lock guard
  // ─────────────────────────────────────────────────────────────

  Future<void> _guardDeliveryLock(bool enforce) async {
    if (!enforce) return;
    final session = ref.read(deliverySessionEngineProvider);
    if (session.isActive) {
      final email = session.enteredByEmail ?? '(unknown)';
      throw DeliveryLockedException(
        'Stock changes are blocked while delivery ${session.deliveryId} is open for $email.',
      );
    }
  }
}
