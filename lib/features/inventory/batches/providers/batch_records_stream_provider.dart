// lib/features/inventory/batches/providers/batch_records_stream_provider.dart

import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batchRecordsStreamProvider = StreamProvider.autoDispose
    .family<List<BatchRecord>, String>((ref, tenantId) {
      final cleanTenantId = tenantId.trim();

      if (cleanTenantId.isEmpty) {
        return Stream.value(const <BatchRecord>[]);
      }

      return db
          .collectionGroup('batches')
          .where('tenantId', isEqualTo: cleanTenantId)
          .snapshots()
          .map((snapshot) {
            if (kDebugMode) {
              debugPrint(
                '📡 [batches.stream] '
                'tenant=$cleanTenantId '
                'docs=${snapshot.size}',
              );
            }

            final records = <BatchRecord>[];

            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();

                // Extra defensive tenant check.
                //
                // The Firestore query + security rules already enforce this,
                // but this prevents malformed documents from entering the UI.
                final docTenantId = data['tenantId']?.toString().trim();

                if (docTenantId != cleanTenantId) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ [batches.stream] '
                      'Skipping tenant mismatch '
                      '${doc.reference.path} '
                      'tenantId=$docTenantId',
                    );
                  }

                  continue;
                }

                // A batch must belong to an inventory item.
                final itemId = (data['itemId'] ?? data['item_id'])
                    ?.toString()
                    .trim();

                if (itemId == null || itemId.isEmpty) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ [batches.stream] '
                      'Skipping batch with no itemId: '
                      '${doc.reference.path}',
                    );
                  }

                  continue;
                }

                records.add(BatchRecord.fromSnapshot(doc));
              } catch (e, st) {
                if (kDebugMode) {
                  debugPrint(
                    '⚠️ [batches.stream] '
                    'Skipping malformed batch '
                    '${doc.reference.path}: '
                    '$e\n$st',
                  );
                }
              }
            }

            // Newest received first.
            //
            // If receivedDate is equal/missing, prefer the batch with
            // the farthest expiry date, then use id as a stable fallback.
            records.sort((a, b) {
              final byReceived = _compareDateDesc(
                a.receivedDate,
                b.receivedDate,
              );

              if (byReceived != 0) {
                return byReceived;
              }

              final byExpiry = _compareDateDesc(a.expiryDate, b.expiryDate);

              if (byExpiry != 0) {
                return byExpiry;
              }

              return b.id.compareTo(a.id);
            });

            if (kDebugMode) {
              debugPrint(
                '📦 [batches.stream] '
                'tenant=$cleanTenantId '
                'yielded=${records.length}',
              );
            }

            return records;
          });
    });

int _compareDateDesc(DateTime? a, DateTime? b) {
  if (a == null && b == null) {
    return 0;
  }

  if (a == null) {
    return 1;
  }

  if (b == null) {
    return -1;
  }

  return b.compareTo(a);
}
