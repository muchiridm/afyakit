// lib/core/records/issues/services/issue_service.dart

import 'dart:convert';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:afyakit/shared/utils/firestore_instance.dart';

import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';

class IssueService {
  final String tenantId;
  IssueService(this.tenantId);

  // Single canonical collection
  static const String _collectionName = 'issue_records';

  CollectionReference<Map<String, dynamic>> get _issuesCol =>
      db.collection('tenants').doc(tenantId).collection(_collectionName);

  DocumentReference<Map<String, dynamic>> _issueRef(String id) =>
      _issuesCol.doc(id);

  CollectionReference<Map<String, dynamic>> _entriesCol(String issueId) =>
      _issueRef(issueId).collection('issue_entries');

  // ─────────────────────────────────────────────────────────────
  // Helpers
  // ─────────────────────────────────────────────────────────────

  /// Firestore doc IDs cannot contain '/', use base64url for safety.
  String _safeDocIdFromRequestKey(String requestKey) {
    final enc = base64Url.encode(utf8.encode(requestKey)).replaceAll('=', '');
    return 'iss_${tenantId}_$enc';
  }

  /// Deterministic sort so entry IDs are stable across retries.
  List<IssueEntry> _stableSortEntries(List<IssueEntry> entries) {
    final list = [...entries];
    list.sort((a, b) {
      var c = a.itemId.compareTo(b.itemId);
      if (c != 0) return c;
      final ab = (a.batchId ?? '');
      final bb = (b.batchId ?? '');
      c = ab.compareTo(bb);
      if (c != 0) return c;
      // fallback for consistent tie-break
      return a.id.compareTo(b.id);
    });
    return list;
  }

  // ─────────────────────────────────────────────────────────────
  // Idempotent create (issue + entries)
  // ─────────────────────────────────────────────────────────────

  /// Creates (or safely re-creates) an issue + entries in an idempotent way.
  /// - Issue doc id is derived from `requestKey` (deterministic).
  /// - Entry doc ids are deterministic: e_0000, e_0001, … (stable sort).
  /// - If re-run with the same `requestKey`, we **update** the issue and
  ///   **replace** the entry set (delete stale ones, upsert the current list).
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

    // ---- 1) Upsert the issue document (idempotent) ----
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

    // ---- 2) Deterministic entry IDs (e_0000, e_0001, …) ----
    final sorted = _stableSortEntries(entries);
    final newIds = List.generate(
      sorted.length,
      (i) => 'e_${i.toString().padLeft(4, '0')}',
    );

    // delete stale entries, upsert current ones
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

    // ---- 3) Back-compat: mirror a read-only `entries` array on the issue doc ----
    // Many of your screens build the list from issue.entries; give them data.
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

  // ─────────────────────────────────────────────────────────────
  // Legacy / utility APIs
  // ─────────────────────────────────────────────────────────────

  /// Non-idempotent helper (kept for admin/backfill tooling).
  Future<void> addIssueWithEntries(
    IssueRecord issue,
    List<IssueEntry> entries,
  ) async {
    final id = issue.id.isNotEmpty ? issue.id : _issuesCol.doc().id;
    final record = issue.copyWith(id: id);
    final ref = _issueRef(id);
    final batch = db.batch();

    try {
      batch.set(ref, record.toMap());
      for (final entry in entries) {
        batch.set(_entriesCol(id).doc(entry.id), entry.toMap());
      }
      await batch.commit();
    } catch (e, st) {
      debugPrint('❌ Failed to add issue with entries: $e\n$st');
      rethrow;
    }
  }

  Future<void> addIssue(IssueRecord issue) async {
    final id = issue.id.isNotEmpty ? issue.id : _issuesCol.doc().id;
    await _issueRef(id).set(issue.copyWith(id: id).toMap());
  }

  Future<void> updateIssue(IssueRecord record) async {
    await _issueRef(record.id).update(record.toMap());
  }

  Future<void> deleteIssue(String id) async {
    await _issueRef(id).delete();
  }

  Future<void> deleteEntriesForIssue(String issueId) async {
    final snapshot = await _entriesCol(issueId).get();
    final batch = db.batch();
    for (final doc in snapshot.docs) {
      batch.delete(doc.reference);
    }
    await batch.commit();
  }

  Future<List<IssueRecord>> getAllIssues() async {
    try {
      final snapshot = await _issuesCol
          .orderBy('dateRequested', descending: true)
          .get();
      return snapshot.docs
          .map((doc) => IssueRecord.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to load issues: $e');
      return [];
    }
  }

  Future<IssueRecord?> getIssueById(String id) async {
    try {
      final doc = await _issueRef(id).get();
      if (!doc.exists) return null;
      return IssueRecord.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('❌ Failed to fetch issue $id: $e');
      return null;
    }
  }

  Future<List<IssueEntry>> getEntriesForIssue(String issueId) async {
    try {
      final snapshot = await _entriesCol(issueId).get();
      return snapshot.docs
          .map((doc) => IssueEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to fetch entries for issue $issueId: $e');
      return [];
    }
  }

  Future<IssueRecord?> getFullIssue(String issueId) async {
    final issue = await getIssueById(issueId);
    if (issue == null) return null;
    final entries = await getEntriesForIssue(issueId);
    return issue.copyWith(entries: entries);
  }
}
