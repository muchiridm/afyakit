import 'dart:async';
// FirebaseException, Query*
import 'package:afyakit/features/batches/models/batch_record.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';

// lib/.../batch_repo.dart
class BatchRepo {
  Future<List<BatchRecord>> fetch(String tenantId) async {
    try {
      debugPrint(
        '🔎 [BatchRepo.fetch] tenant=$tenantId → CG query (tenant filter)…',
      );
      final snap = await db
          .collectionGroup('batches')
          .where('tenantId', isEqualTo: tenantId) // ← REQUIRED
          .get();

      debugPrint('✅ [BatchRepo.fetch] docs=${snap.size}');
      return snap.docs.map(BatchRecord.fromSnapshot).toList();
    } on FirebaseException catch (e, st) {
      debugPrint('❌ [BatchRepo.fetch] code=${e.code} msg=${e.message}\n$st');
      rethrow;
    }
  }

  Stream<List<BatchRecord>> stream(String tenantId) {
    return db
        .collectionGroup('batches')
        .where('tenantId', isEqualTo: tenantId) // ← REQUIRED
        .snapshots()
        .handleError((e, st) {
          debugPrint('❌ [BatchRepo.stream] $e\n$st');
        })
        .map((s) {
          debugPrint('📡 [BatchRepo.stream] tenant=$tenantId → docs=${s.size}');
          return s.docs.map(BatchRecord.fromSnapshot).toList();
        });
  }
}
