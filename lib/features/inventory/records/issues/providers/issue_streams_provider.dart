import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_record.dart';
import 'package:afyakit/features/inventory/records/issues/models/issue_entry.dart';
import 'package:afyakit/features/inventory/records/issues/services/issue_service.dart';

/// Bundle used to identify a single issue in a tenant.
typedef IssueKey = ({String tenantId, String issueId});

/// 🔹 Kick a one-time backfill per tenant (idempotent).
/// It writes missing `brand` and `expiry` into issue_entries and then
/// sets a marker so it never runs again for this tenant.
final _brandExpiryBackfillTriggerProvider = FutureProvider.family<void, String>(
  (ref, tenantId) async {
    try {
      final svc = IssueService(tenantId);
      await svc.runBrandExpiryBackfillIfNeeded(); // idempotent
    } catch (e, st) {
      debugPrint('↯ backfill trigger failed for $tenantId → $e\n$st');
    }
  },
);

/// 1) Live list of issues for a tenant (newest → oldest)
final issuesStreamProvider = StreamProvider.family
    .autoDispose<List<IssueRecord>, String>((ref, tenantId) {
      // 🔸 Ensure the backfill runs once in the background (idempotent).
      ref.watch(_brandExpiryBackfillTriggerProvider(tenantId));

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

/// 2) Live single issue document
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

/// 3) Live entries (subcollection) for a single issue
///
/// These entry docs should already contain *all* denormalized SKU info:
/// itemName, itemGroup, strength, packSize, **brand**, and optionally expiry.
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

/// 4) Combined provider: glue doc + entries into one IssueRecord (no extra reads)
final issueFullProvider = Provider.family
    .autoDispose<AsyncValue<IssueRecord?>, IssueKey>((ref, key) {
      final docAsync = ref.watch(issueDocStreamProvider(key));
      final entriesAsync = ref.watch(issueEntriesStreamProvider(key));

      if (docAsync.isLoading || entriesAsync.isLoading) {
        return const AsyncLoading();
      }
      if (docAsync.hasError) {
        return AsyncError(
          docAsync.error!,
          docAsync.stackTrace ?? StackTrace.current,
        );
      }
      if (entriesAsync.hasError) {
        return AsyncError(
          entriesAsync.error!,
          entriesAsync.stackTrace ?? StackTrace.current,
        );
      }

      final issue = docAsync.value;
      if (issue == null) return const AsyncData<IssueRecord?>(null);

      final entries = entriesAsync.value ?? const <IssueEntry>[];
      return AsyncData<IssueRecord?>(issue.copyWith(entries: entries));
    });
