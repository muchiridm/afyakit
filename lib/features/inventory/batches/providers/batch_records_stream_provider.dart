import 'package:afyakit/app/providers/app_profile_provider.dart';
import 'package:afyakit/features/inventory/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batchRecordsStreamProvider = StreamProvider.autoDispose
    .family<List<BatchRecord>, String>((ref, tenantId) {
      final cleanTenantId = tenantId.trim().toLowerCase();
      final appId = ref.watch(appIdProvider).trim().toLowerCase();

      if (cleanTenantId.isEmpty || appId.isEmpty) {
        return Stream.value(const <BatchRecord>[]);
      }

      return db
          .collectionGroup('batches')
          .where('tenantId', isEqualTo: cleanTenantId)
          .where('app_id', isEqualTo: appId)
          .snapshots()
          .map((snapshot) {
            if (kDebugMode) {
              debugPrint(
                '📡 [batches.stream] '
                'tenant=$cleanTenantId '
                'app=$appId '
                'docs=${snapshot.size}',
              );
            }

            final records = <BatchRecord>[];

            for (final doc in snapshot.docs) {
              try {
                final data = doc.data();

                final docTenantId = data['tenantId']
                    ?.toString()
                    .trim()
                    .toLowerCase();
                final docAppId = data['app_id']
                    ?.toString()
                    .trim()
                    .toLowerCase();

                if (docTenantId != cleanTenantId || docAppId != appId) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️ [batches.stream] '
                      'Skipping scope mismatch '
                      '${doc.reference.path} '
                      'tenantId=$docTenantId '
                      'app_id=$docAppId',
                    );
                  }

                  continue;
                }

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
                'app=$appId '
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
