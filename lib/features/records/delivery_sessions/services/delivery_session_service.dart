// lib/features/records/delivery_sessions/services/delivery_session_service.dart

import 'package:afyakit/features/records/delivery_sessions/models/delivery_record.dart';
import 'package:afyakit/features/records/delivery_sessions/models/temp_session.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/foundation.dart';

enum SaveResult { saved, alreadySaved }

class DeliverySessionService {
  final FirebaseFirestore _firestore = db;

  // ─────────────────────────────────────────────
  // 🔎 Resume an open (unfinalized) temp session
  // ─────────────────────────────────────────────
  Future<TempSession?> findOpenSession({
    required String tenantId,
    required String enteredByEmail,
  }) async {
    final email = enteredByEmail.trim().toLowerCase();

    final snap = await _firestore
        .collection('tenants/$tenantId/delivery_sessions_temp')
        .where('entered_by_email', isEqualTo: email)
        .where('is_finalized', isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return null;

    // Prefer newest by started_at; fallback to delivery_id
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final ta = a.data()['started_at'];
        final tb = b.data()['started_at'];
        if (ta is Timestamp && tb is Timestamp) return tb.compareTo(ta);
        final ida = a.data()['delivery_id'] as String? ?? '';
        final idb = b.data()['delivery_id'] as String? ?? '';
        return idb.compareTo(ida);
      });

    final d = docs.first.data();
    return TempSession(
      deliveryId: d['delivery_id'] as String,
      enteredByName: d['entered_by_name'] as String?,
      enteredByEmail: d['entered_by_email'] as String,
      sources: (d['sources'] as List<dynamic>? ?? const []).cast<String>(),
      lastStoreId: d['last_store_id'] as String?,
      lastSource: d['last_source'] as String?,
    );
  }

  // ─────────────────────────────────────────────
  // 🧾 Create/update temp session (don’t bump started_at)
  // ─────────────────────────────────────────────
  Future<void> upsertTempSession({
    required String tenantId,
    required String deliveryId,
    required String enteredByEmail,
    required String enteredByName,
    List<String> sources = const [],
  }) async {
    final email = enteredByEmail.trim().toLowerCase();
    final ref = _firestore
        .collection('tenants/$tenantId/delivery_sessions_temp')
        .doc(deliveryId);

    await _firestore.runTransaction((txn) async {
      final snap = await txn.get(ref);

      if (!snap.exists) {
        txn.set(ref, {
          'delivery_id': deliveryId,
          'entered_by_email': email,
          'entered_by_name': enteredByName,
          'sources': sources,
          'is_finalized': false,
          'batches_count': 0,
          'started_at': FieldValue.serverTimestamp(),
          'expires_at': null,
        });
      } else {
        final prevSources =
            (snap.data()?['sources'] as List<dynamic>? ?? const [])
                .cast<String>();
        final merged = {...prevSources, ...sources}.toList();

        txn.update(ref, {
          'entered_by_email': email,
          'entered_by_name': enteredByName,
          'sources': merged,
          'is_finalized': false,
        });
      }
    });
  }

  // ─────────────────────────────────────────────
  // ✅ Mark temp session finalized
  // ─────────────────────────────────────────────
  Future<void> finalizeTempSession({
    required String tenantId,
    required String deliveryId,
    required int batchesCount,
  }) async {
    final ref = _firestore
        .collection('tenants/$tenantId/delivery_sessions_temp')
        .doc(deliveryId);

    await ref.set({
      'is_finalized': true,
      'batches_count': batchesCount,
      'finalized_at': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ─────────────────────────────────────────────
  // 💾 Final save (idempotent)
  // ─────────────────────────────────────────────
  Future<SaveResult> saveDeliverySession({
    required String tenantId,
    required DeliveryRecord record,
  }) async {
    final docRef = _firestore.doc(
      'tenants/$tenantId/delivery_records/${record.deliveryId}',
    );

    final existing = await docRef.get();
    if (existing.exists) {
      debugPrint(
        'ℹ️ [Delivery] ${record.deliveryId} already exists → idempotent OK',
      );
      return SaveResult.alreadySaved;
    }

    await docRef.set(record.toMap(), SetOptions(merge: false));
    debugPrint('✅ [Delivery] Saved ${record.deliveryId}');
    return SaveResult.saved;
  }

  // ─────────────────────────────────────────────
  // ✍️ Persist “last used” prefs for UX prefill
  // ─────────────────────────────────────────────
  Future<void> updateLastPrefs({
    required String tenantId,
    required String deliveryId,
    String? lastStoreId,
    String? lastSource,
  }) async {
    final ref = _firestore
        .collection('tenants/$tenantId/delivery_sessions_temp')
        .doc(deliveryId);

    final data = <String, dynamic>{};
    if (lastStoreId != null) data['last_store_id'] = lastStoreId;
    if (lastSource != null) data['last_source'] = lastSource;

    if (data.isNotEmpty) {
      await ref.set(data, SetOptions(merge: true));
    }
  }
}
