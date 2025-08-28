import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/core/records/issues/models/issue_record.dart';
import 'package:afyakit/core/records/issues/models/issue_entry.dart';

final hydratedIssuesStreamProvider = StreamProvider.family
    .autoDispose<List<IssueRecord>, String>((ref, tenantId) {
      final collection = db
          .collection('tenants')
          .doc(tenantId)
          .collection('issue_records')
          .orderBy('dateRequested', descending: true);

      return collection.snapshots().asyncMap((snapshot) async {
        final List<IssueRecord> hydrated = [];

        for (final doc in snapshot.docs) {
          final data = doc.data();
          final recordId = doc.id;

          // Fetch entries subcollection
          final entriesSnapshot = await db
              .collection('tenants')
              .doc(tenantId)
              .collection('issue_records')
              .doc(recordId)
              .collection('issue_entries')
              .get();

          final entries = entriesSnapshot.docs
              .map((e) => IssueEntry.fromMap(e.id, e.data()))
              .toList();

          final issue = IssueRecord.fromMap(
            recordId,
            data,
          ).copyWith(entries: entries);
          hydrated.add(issue);
        }

        return hydrated;
      });
    });
