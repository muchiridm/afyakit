// lib/core/records/issues/providers/issue_streams_provider.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/models/issue_entry.dart';

/// Live list of issues (ordered newest → oldest).
final issuesStreamProvider = StreamProvider.family
    .autoDispose<List<IssueRecord>, String>((ref, tenantId) {
      final q = db
          .collection('tenants')
          .doc(tenantId)
          .collection('issue_records')
          .orderBy('dateRequested', descending: true);

      return q.snapshots().map(
        (snap) =>
            snap.docs.map((d) => IssueRecord.fromMap(d.id, d.data())).toList(),
      );
    });

/// Param bundle for per-issue providers.
typedef IssueKey = ({String tenantId, String issueId});

/// Live **document** stream for a single issue.
final issueDocStreamProvider = StreamProvider.family
    .autoDispose<IssueRecord?, IssueKey>((ref, key) {
      final docRef = db
          .collection('tenants')
          .doc(key.tenantId)
          .collection('issue_records')
          .doc(key.issueId);

      return docRef.snapshots().map(
        (s) => s.exists ? IssueRecord.fromMap(s.id, s.data()!) : null,
      );
    });

/// Live **entries** stream (subcollection) for a single issue.
final issueEntriesStreamProvider = StreamProvider.family
    .autoDispose<List<IssueEntry>, IssueKey>((ref, key) {
      final col = db
          .collection('tenants')
          .doc(key.tenantId)
          .collection('issue_records')
          .doc(key.issueId)
          .collection('issue_entries');

      return col.snapshots().map(
        (qs) => qs.docs.map((e) => IssueEntry.fromMap(e.id, e.data())).toList(),
      );
    });

/// Combined doc + entries as a single AsyncValue<IssueRecord?> (no `.stream` use).
final issueFullProvider = Provider.family
    .autoDispose<AsyncValue<IssueRecord?>, IssueKey>((ref, key) {
      final doc = ref.watch(
        issueDocStreamProvider(key),
      ); // AsyncValue<IssueRecord?>
      final ents = ref.watch(
        issueEntriesStreamProvider(key),
      ); // AsyncValue<List<IssueEntry>>

      // Loading
      if (doc.isLoading || ents.isLoading) {
        return const AsyncLoading<IssueRecord?>();
      }

      // Errors (coalesce nullable stack traces)
      if (doc.hasError) {
        return AsyncError<IssueRecord?>(
          doc.error!,
          doc.stackTrace ?? StackTrace.current,
        );
      }
      if (ents.hasError) {
        return AsyncError<IssueRecord?>(
          ents.error!,
          ents.stackTrace ?? StackTrace.current,
        );
      }

      // Data
      final d = doc.value;
      if (d == null) return const AsyncData<IssueRecord?>(null);

      return AsyncData<IssueRecord?>(
        d.copyWith(entries: ents.value ?? d.entries),
      );
    });
