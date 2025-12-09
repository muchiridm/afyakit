// lib/features/batches/providers/batch_records_stream_provider.dart
import 'package:afyakit/modules/inventory/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batchRecordsStreamProvider = StreamProvider.autoDispose
    .family<List<BatchRecord>, String>((ref, tenantId) {
      return db
          .collectionGroup('batches')
          // Required discriminator for collectionGroup + rules
          .where('tenantId', isEqualTo: tenantId)
          .snapshots()
          .map((snap) {
            if (kDebugMode) {
              debugPrint(
                '📡 [batches.stream] tenant=$tenantId → docs=${snap.size}',
              );
            }

            final out = <BatchRecord>[];

            for (final doc in snap.docs) {
              try {
                // Light guard so a missing itemId doesn't throw inside the model
                final data = doc.data();
                final rawItemId = (data['itemId'] ?? data['item_id'])
                    ?.toString()
                    .trim();
                if (rawItemId == null || rawItemId.isEmpty) {
                  if (kDebugMode) {
                    debugPrint(
                      '⚠️  Skipping batch with no itemId: ${doc.reference.path}',
                    );
                  }
                  continue;
                }

                out.add(BatchRecord.fromSnapshot(doc));
              } catch (e, st) {
                if (kDebugMode) {
                  debugPrint(
                    '⚠️  Skipping malformed batch ${doc.reference.path}: $e\n$st',
                  );
                }
              }
            }

            // Sort: newest received first, then farthest expiry, then id
            int cmpDate(DateTime? a, DateTime? b) {
              if (a == null && b == null) return 0;
              if (a == null) return 1;
              if (b == null) return -1;
              return b.compareTo(a); // desc
            }

            out.sort((a, b) {
              final byReceived = cmpDate(a.receivedDate, b.receivedDate);
              if (byReceived != 0) return byReceived;
              final byExpiry = cmpDate(a.expiryDate, b.expiryDate);
              if (byExpiry != 0) return byExpiry;
              return b.id.compareTo(a.id); // stable fallback
            });

            if (kDebugMode) {
              debugPrint(
                '📦 [batches.stream] yielded ${out.length} valid records',
              );
            }
            return out;
          });
    });
