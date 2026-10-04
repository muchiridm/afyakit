// lib/features/inventory/records/issues/providers/issue_streams_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart';

import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_entry.dart';

/// Identifies a single issue within a tenant.
typedef IssueKey = ({String tenantId, String issueId});

/// ─────────────────────────────────────────────
/// 1. Live issue list
/// ─────────────────────────────────────────────

final issuesStreamProvider = StreamProvider.family
    .autoDispose<List<IssueRecord>, String>((ref, tenantId) {
      final q = db
          .collection('tenants')
          .doc(tenantId)
          .collection('issue_records')
          .orderBy('dateRequestedTs', descending: true);

      return q.snapshots().map(
        (snap) => snap.docs
            .map((doc) => IssueRecord.fromMap(doc.id, doc.data()))
            .toList(),
      );
    });

/// ─────────────────────────────────────────────
/// 2. Live single issue
/// ─────────────────────────────────────────────

final issueDocStreamProvider = StreamProvider.family
    .autoDispose<IssueRecord?, IssueKey>((ref, key) {
      final docRef = db
          .collection('tenants')
          .doc(key.tenantId)
          .collection('issue_records')
          .doc(key.issueId);

      return docRef.snapshots().map((snapshot) {
        if (!snapshot.exists) {
          return null;
        }

        return IssueRecord.fromMap(snapshot.id, snapshot.data()!);
      });
    });

/// ─────────────────────────────────────────────
/// 3. Live issue entries
/// ─────────────────────────────────────────────

final issueEntriesStreamProvider = StreamProvider.family
    .autoDispose<List<IssueEntry>, IssueKey>((ref, key) {
      final col = db
          .collection('tenants')
          .doc(key.tenantId)
          .collection('issue_records')
          .doc(key.issueId)
          .collection('issue_entries');

      return col.snapshots().map(
        (snapshot) => snapshot.docs
            .map((doc) => IssueEntry.fromMap(doc.id, doc.data()))
            .toList(),
      );
    });

/// ─────────────────────────────────────────────
/// 4. Full issue = record + entries
/// ─────────────────────────────────────────────

final issueFullProvider = Provider.family
    .autoDispose<AsyncValue<IssueRecord?>, IssueKey>((ref, key) {
      final issueAsync = ref.watch(issueDocStreamProvider(key));

      final entriesAsync = ref.watch(issueEntriesStreamProvider(key));

      if (issueAsync.isLoading || entriesAsync.isLoading) {
        return const AsyncLoading();
      }

      if (issueAsync.hasError) {
        return AsyncError(
          issueAsync.error!,
          issueAsync.stackTrace ?? StackTrace.current,
        );
      }

      if (entriesAsync.hasError) {
        return AsyncError(
          entriesAsync.error!,
          entriesAsync.stackTrace ?? StackTrace.current,
        );
      }

      final issue = issueAsync.value;

      if (issue == null) {
        return const AsyncData<IssueRecord?>(null);
      }

      final entries = entriesAsync.value ?? const <IssueEntry>[];

      return AsyncData<IssueRecord?>(issue.copyWith(entries: entries));
    });
