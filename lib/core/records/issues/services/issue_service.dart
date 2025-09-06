import 'package:afyakit/core/records/issues/models/issue_entry.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/material.dart';

class IssueService {
  final String tenantId;

  IssueService(this.tenantId);

  CollectionReference<Map<String, dynamic>> get _collection =>
      db.collection('tenants').doc(tenantId).collection('issue_records');

  DocumentReference<Map<String, dynamic>> _docRef(String id) =>
      _collection.doc(id);

  CollectionReference<Map<String, dynamic>> _entryCollection(String issueId) =>
      _docRef(issueId).collection('issue_entries');

  /// ➕ Create record + entries
  Future<void> addIssueWithEntries(
    IssueRecord issue,
    List<IssueEntry> entries,
  ) async {
    final id = issue.id.isNotEmpty ? issue.id : _collection.doc().id;
    final record = issue.copyWith(id: id);
    final ref = _docRef(id);
    final batch = db.batch();

    try {
      // 🔍 Log the record
      debugPrint('📄 Saving IssueRecord: ${record.toMap()}');
      batch.set(ref, record.toMap());

      for (final entry in entries) {
        final entryRef = _entryCollection(id).doc(entry.id);
        final map = entry.toMap();

        // 🔍 Log each entry
        debugPrint('🧾 Saving Entry (${entry.id}): $map');

        batch.set(entryRef, map);
      }

      await batch.commit();
      debugPrint('✅ Batch write successful');
    } catch (e, st) {
      debugPrint('❌ Failed to add issue with entries: $e');
      debugPrint('🧱 Stack trace:\n$st');
      rethrow;
    }
  }

  /// ➕ Just the record (no entries)
  Future<void> addIssue(IssueRecord issue) async {
    final id = issue.id.isNotEmpty ? issue.id : _collection.doc().id;
    final record = issue.copyWith(id: id);

    try {
      await _docRef(id).set(record.toMap());
    } catch (e) {
      debugPrint('❌ Failed to add issue: $e');
      rethrow;
    }
  }

  /// 🔁 Update record
  Future<void> updateIssue(IssueRecord record) async {
    try {
      await _docRef(record.id).update(record.toMap());
    } catch (e) {
      debugPrint('❌ Failed to update issue: $e');
      rethrow;
    }
  }

  /// ❌ Delete record (entries not deleted automatically)
  Future<void> deleteIssue(String id) async {
    try {
      await _docRef(id).delete();
    } catch (e) {
      debugPrint('❌ Failed to delete issue record: $e');
      rethrow;
    }
  }

  /// ❌ Delete all entries for a specific issue
  Future<void> deleteEntriesForIssue(String issueId) async {
    try {
      final snapshot = await _entryCollection(issueId).get();
      final batch = db.batch();

      for (final doc in snapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
    } catch (e) {
      debugPrint('❌ Failed to delete entries for issue $issueId: $e');
      rethrow;
    }
  }

  /// 📥 One-time fetch of all issue records
  Future<List<IssueRecord>> getAllIssues() async {
    try {
      final snapshot = await _collection
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

  /// 📍 Fetch a single issue record by ID
  Future<IssueRecord?> getIssueById(String id) async {
    try {
      final doc = await _docRef(id).get();
      if (!doc.exists) return null;
      return IssueRecord.fromMap(doc.id, doc.data()!);
    } catch (e) {
      debugPrint('❌ Failed to fetch issue $id: $e');
      return null;
    }
  }

  /// 📄 Get entries for a specific issue
  Future<List<IssueEntry>> getEntriesForIssue(String issueId) async {
    try {
      final snapshot = await _entryCollection(issueId).get();

      return snapshot.docs
          .map((doc) => IssueEntry.fromMap(doc.id, doc.data()))
          .toList();
    } catch (e) {
      debugPrint('❌ Failed to fetch entries for issue $issueId: $e');
      return [];
    }
  }

  /// 📦 Load issue with entries in one go
  Future<IssueRecord?> getFullIssue(String issueId) async {
    final issue = await getIssueById(issueId);
    if (issue == null) return null;

    final entries = await getEntriesForIssue(issueId);
    return issue.copyWith(entries: entries);
  }
}
