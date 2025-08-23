// lib/features/batches/providers/batch_records_stream_provider.dart
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final batchRecordsStreamProvider = StreamProvider.autoDispose
    .family<List<BatchRecord>, String>((ref, tenantId) {
      return db
          .collectionGroup('batches')
          .where('tenantId', isEqualTo: tenantId) // ✅ required for CG + rules
          .snapshots()
          .map((snap) {
            if (kDebugMode) {
              debugPrint(
                '📡 [batches.stream] tenant=$tenantId → docs=${snap.size}',
              );
            }
            return snap.docs.map(BatchRecord.fromSnapshot).toList();
          });
    });
