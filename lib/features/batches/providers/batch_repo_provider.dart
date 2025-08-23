import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/features/batches/services/batch_repo.dart';
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/features/tenants/providers/tenant_id_provider.dart';

final batchRepoProvider = Provider.autoDispose<BatchRepo>((_) => BatchRepo());

final tenantBatchesOnceProvider = FutureProvider.autoDispose<List<BatchRecord>>(
  (ref) {
    final tenantId = ref.watch(tenantIdProvider);
    final repo = ref.read(batchRepoProvider);
    return repo.fetch(tenantId);
  },
);

final tenantBatchesStreamProvider =
    StreamProvider.autoDispose<List<BatchRecord>>((ref) {
      final tenantId = ref.watch(tenantIdProvider);
      final repo = ref.read(batchRepoProvider);

      final link = ref.keepAlive();
      Timer? purge;
      ref.onCancel(
        () => purge = Timer(const Duration(seconds: 20), link.close),
      );
      ref.onResume(() => purge?.cancel());

      return repo.stream(tenantId);
    });

final batchesOnceByTenantProvider = FutureProvider.autoDispose
    .family<List<BatchRecord>, String>((ref, tid) {
      final repo = ref.read(batchRepoProvider);
      return repo.fetch(tid);
    });
