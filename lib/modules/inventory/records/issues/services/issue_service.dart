// lib/core/records/issues/services/issue_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:afyakit/shared/utils/firestore_instance.dart';

import 'package:afyakit/modules/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/modules/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/modules/inventory/items/extensions/item_type_x.dart';

class IssueService {
  final String tenantId;
  IssueService(this.tenantId);

  static const String _collectionName = 'issue_records';

  CollectionReference<Map<String, dynamic>> get _issuesCol =>
      db.collection('tenants').doc(tenantId).collection(_collectionName);

  DocumentReference<Map<String, dynamic>> _issueRef(String id) =>
      _issuesCol.doc(id);

  CollectionReference<Map<String, dynamic>> _entriesCol(String issueId) =>
      _issueRef(issueId).collection('issue_entries');

  // ─────────────────────────────────────────────
  // helpers
  // ─────────────────────────────────────────────

  String _safeDocIdFromRequestKey(String requestKey) {
    final enc = base64Url.encode(utf8.encode(requestKey)).replaceAll('=', '');
    return 'iss_${tenantId}_$enc';
  }

  List<IssueEntry> _stableSortEntries(List<IssueEntry> entries) {
    final list = [...entries];
    list.sort((a, b) {
      var c = a.itemId.compareTo(b.itemId);
      if (c != 0) return c;
      c = (a.batchId ?? '').compareTo(b.batchId ?? '');
      if (c != 0) return c;
      return a.id.compareTo(b.id);
    });
    return list;
  }

  // ─────────────────────────────────────────────
  // create / update
  // ─────────────────────────────────────────────

  Future<String> createIssueWithEntriesIdempotent({
    required String requestKey,
    required IssueRecord issueDraft,
    required List<IssueEntry> entries,
  }) async {
    if (requestKey.trim().isEmpty) {
      throw ArgumentError('requestKey must not be empty');
    }

    final issueId = _safeDocIdFromRequestKey(requestKey);
    final issueRef = _issueRef(issueId);
    final entryCol = _entriesCol(issueId);

    await db.runTransaction((tx) async {
      final snap = await tx.get(issueRef);

      final rec = issueDraft.copyWith(id: issueId);
      final data = rec.toMap()
        ..['tenantId'] = tenantId
        ..['requestKey'] = requestKey
        ..putIfAbsent(
          'dateRequestedTs',
          () => Timestamp.fromDate(rec.dateRequested),
        );

      final toWrite = <String, Object?>{
        ...data,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (!snap.exists) {
        toWrite['createdAt'] = FieldValue.serverTimestamp();
      }
      tx.set(issueRef, toWrite, SetOptions(merge: true));
    });

    final sorted = _stableSortEntries(entries);
    final newIds = List.generate(
      sorted.length,
      (i) => 'e_${i.toString().padLeft(4, '0')}',
    );

    final existingSnap = await entryCol.get();
    final batch = db.batch();

    for (final d in existingSnap.docs) {
      if (!newIds.contains(d.id)) batch.delete(d.reference);
    }

    for (var i = 0; i < sorted.length; i++) {
      batch.set(
        entryCol.doc(newIds[i]),
        sorted[i].toMap(),
        SetOptions(merge: true),
      );
    }
    await batch.commit();

    await issueRef.update({
      'entries': sorted.map((e) => e.toMap()).toList(),
      'entryCount': sorted.length,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    debugPrint(
      '✅ createIssueWithEntriesIdempotent issue=$issueId (entries=${sorted.length}, deleted=${existingSnap.docs.length - newIds.length})',
    );

    return issueId;
  }

  // legacy utility

  Future<List<IssueRecord>> getAllIssues() async {
    final snapshot = await _issuesCol
        .orderBy('dateRequested', descending: true)
        .get();
    return snapshot.docs
        .map((doc) => IssueRecord.fromMap(doc.id, doc.data()))
        .toList();
  }

  Future<List<IssueEntry>> getEntriesForIssue(String issueId) async {
    final snapshot = await _entriesCol(issueId).get();
    return snapshot.docs
        .map((doc) => IssueEntry.fromMap(doc.id, doc.data()))
        .toList();
  }

  // ─────────────────────────────────────────────
  // ONE-TIME (BUT FORCEABLE) BACKFILL
  // ─────────────────────────────────────────────

  /// Run this once per tenant to populate `brand` and `expiry` on old
  /// issue_entries. Pass `force: true` while testing so you can see logs.
  Future<void> runBrandExpiryBackfillIfNeeded({bool force = false}) async {
    final marker = db
        .collection('tenants')
        .doc(tenantId)
        .collection('meta')
        .doc('backfill_brand_expiry_v1');

    final markerSnap = await marker.get();
    final alreadyDone =
        markerSnap.exists && (markerSnap.data()?['completed'] == true);

    if (alreadyDone && !force) {
      debugPrint('↪︎ backfill skipped for $tenantId (already done)');
      return;
    }

    debugPrint('⏳ starting brand/expiry backfill for $tenantId ...');

    final issuesSnap = await _issuesCol.get();
    var totalUpdates = 0;

    for (final issueDoc in issuesSnap.docs) {
      final issueId = issueDoc.id;
      final issue = IssueRecord.fromMap(issueId, issueDoc.data());
      final entriesSnap = await _entriesCol(issueId).get();

      var batch = db.batch();
      var ops = 0;

      for (final eDoc in entriesSnap.docs) {
        final entryId = eDoc.id;
        final entry = IssueEntry.fromMap(entryId, eDoc.data());

        final needsBrand = entry.brand == null || entry.brand!.trim().isEmpty;
        final needsExpiry = entry.expiry == null;

        if (!needsBrand && !needsExpiry) continue;

        final update = <String, Object?>{};

        // try to resolve brand first
        if (needsBrand) {
          final brand = await _resolveBrandForEntry(
            entry: entry,
            issueFromStore: issue.fromStore,
          );
          if (brand != null && brand.trim().isNotEmpty) {
            update['brand'] = brand.trim();
            debugPrint(
              '✅ brand backfilled: issue=$issueId entry=$entryId item=${entry.itemId} → "$brand"',
            );
          } else {
            debugPrint(
              '⚠️ brand NOT found: issue=$issueId entry=$entryId item=${entry.itemId} type=${entry.itemType}',
            );
          }
        }

        // expiry from batch
        if (needsExpiry) {
          final iso = await _resolveBatchExpiryIso(
            fromStore: issue.fromStore,
            batchId: entry.batchId,
          );
          if (iso != null) {
            update['expiry'] = iso;
            debugPrint(
              '✅ expiry backfilled: issue=$issueId entry=$entryId batch=${entry.batchId} → $iso',
            );
          } else {
            debugPrint(
              '⚠️ expiry NOT found: issue=$issueId entry=$entryId batch=${entry.batchId}',
            );
          }
        }

        if (update.isEmpty) continue;

        batch.update(eDoc.reference, update);
        ops++;
        totalUpdates++;

        if (ops >= 400) {
          await batch.commit();
          batch = db.batch();
          ops = 0;
        }
      }

      if (ops > 0) {
        await batch.commit();
      }
    }

    await marker.set({
      'completed': true,
      'updatedCount': totalUpdates,
      'completedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    debugPrint(
      '✅ backfill brand/expiry finished for $tenantId → $totalUpdates entries updated',
    );
  }

  /// Try item collections first, then batch.
  Future<String?> _resolveBrandForEntry({
    required IssueEntry entry,
    required String issueFromStore,
  }) async {
    // 1) try item collection based on itemType
    String? col;
    switch (entry.itemType) {
      case ItemType.medication:
        col = 'medications';
        break;
      case ItemType.consumable:
        col = 'consumables';
        break;
      case ItemType.equipment:
        col = 'equipment';
        break;
      case ItemType.unknown:
        col = null;
        break;
    }

    if (col != null) {
      final itemSnap = await db
          .collection('tenants')
          .doc(tenantId)
          .collection(col)
          .doc(entry.itemId)
          .get();

      final itemData = itemSnap.data();
      if (itemData != null) {
        // these are the most likely keys
        final bn = (itemData['brandName'] ?? itemData['brand'])?.toString();
        if (bn != null && bn.trim().isNotEmpty) {
          return bn.trim();
        }
      }
    }

    // 2) fallback: some people store brand on the batch
    if (entry.batchId != null && entry.batchId!.trim().isNotEmpty) {
      final bSnap = await db
          .collection('tenants')
          .doc(tenantId)
          .collection('stores')
          .doc(issueFromStore)
          .collection('batches')
          .doc(entry.batchId!)
          .get();

      final bData = bSnap.data();
      if (bData != null) {
        final bn = (bData['brandName'] ?? bData['brand'])?.toString();
        if (bn != null && bn.trim().isNotEmpty) {
          return bn.trim();
        }
      }
    }

    return null;
  }

  Future<String?> _resolveBatchExpiryIso({
    required String fromStore,
    required String? batchId,
  }) async {
    if (batchId == null || batchId.trim().isEmpty) return null;
    final snap = await db
        .collection('tenants')
        .doc(tenantId)
        .collection('stores')
        .doc(fromStore)
        .collection('batches')
        .doc(batchId)
        .get();

    if (!snap.exists) return null;
    final data = snap.data();
    if (data == null) return null;

    final raw = data['expiryDate'];
    if (raw is Timestamp) return raw.toDate().toIso8601String();
    if (raw is String && raw.isNotEmpty) {
      final dt = DateTime.tryParse(raw);
      return dt?.toIso8601String();
    }
    return null;
  }
}
