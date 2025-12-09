// lib/features/records/delivery_sessions/data/delivery_session_service.dart
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:afyakit/modules/inventory/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/modules/inventory/records/deliveries/controllers/delivery_session_state.dart';
import 'package:afyakit/modules/inventory/records/deliveries/models/delivery_review_summary.dart';
import 'package:afyakit/modules/inventory/batches/providers/batch_records_stream_provider.dart';
import 'package:afyakit/modules/inventory/items/providers/item_stream_providers.dart';
import 'package:afyakit/shared/utils/resolvers/resolve_item_name.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum SaveResult { saved, alreadySaved }

// snake-case collections, camelCase fields
class _K {
  static const collTemp = 'delivery_records_temp';
  static const collRecords = 'delivery_records';
  static const collCounters = 'delivery_id_counters';

  static const deliveryId = 'deliveryId';
  static const enteredByEmail = 'enteredByEmail';
  static const enteredByName = 'enteredByName';
  static const sources = 'sources';
  static const isFinalized = 'isFinalized';
  static const batchesCount = 'batchesCount';
  static const startedAt = 'startedAt';
  static const finalizedAt = 'finalizedAt';
  static const updatedAt = 'updatedAt';
  static const closedAt = 'closedAt';
  static const expiresAt = 'expiresAt';
  static const lastSource = 'lastSource';
  static const lastStoreId = 'lastStoreId';

  static const prefsKey = 'delivery_session_state';
}

@immutable
class TempSession {
  final String deliveryId;
  final String? enteredByName;
  final String enteredByEmail;
  final List<String> sources;
  final String? lastStoreId;
  final String? lastSource;
  const TempSession({
    required this.deliveryId,
    required this.enteredByName,
    required this.enteredByEmail,
    required this.sources,
    this.lastStoreId,
    this.lastSource,
  });
}

class DeliverySessionService {
  final FirebaseFirestore _db = db;

  // ---------- IDs ----------
  Future<String> newDeliveryId(String tenantId) async {
    final now = DateTime.now();
    final dateKey = '${now.year}${_2(now.month)}${_2(now.day)}';
    final ref = _db
        .collection('tenants')
        .doc(tenantId)
        .collection(_K.collCounters)
        .doc(dateKey);

    final next = await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      final current = snap.exists ? (snap.data()?['count'] ?? 0) : 0;
      final n = current + 1;
      txn.set(ref, {'count': n}, SetOptions(merge: true));
      return n;
    });

    return 'DN_${dateKey}_${next.toString().padLeft(3, '0')}';
  }

  // ---------- Temp sessions ----------
  Future<TempSession?> findOpen({
    required String tenantId,
    required String enteredByEmail,
  }) async {
    final email = enteredByEmail.trim().toLowerCase();
    final base = _db.collection('tenants/$tenantId/${_K.collTemp}');

    // Get all open sessions for this user
    final snap = await base
        .where(_K.enteredByEmail, isEqualTo: email)
        .where(_K.isFinalized, isEqualTo: false)
        .get();

    if (snap.docs.isEmpty) return null;

    int ts(dynamic v) => v is Timestamp ? v.millisecondsSinceEpoch : 0;

    // Prefer most recently updated, then most recently started
    final docs = snap.docs.toList()
      ..sort((a, b) {
        final da = a.data(), dbb = b.data();
        final ua = ts(da[_K.updatedAt]);
        final ub = ts(dbb[_K.updatedAt]);
        if (ub != ua) return ub.compareTo(ua);
        final sa = ts(da[_K.startedAt]);
        final sb = ts(dbb[_K.startedAt]);
        return sb.compareTo(sa);
      });

    for (final doc in docs) {
      final d = doc.data();
      final id = (d[_K.deliveryId] as String?)?.trim() ?? '';
      if (id.isEmpty) continue;

      final lastStoreId = (d[_K.lastStoreId] as String?)?.trim();
      final lastSource = (d[_K.lastSource] as String?)?.trim();

      // 1) Prefer store-scoped query (single where → no composite index)
      if (lastStoreId != null && lastStoreId.isNotEmpty) {
        final s = await _db
            .collection('tenants/$tenantId/stores/$lastStoreId/batches')
            .where('deliveryId', isEqualTo: id)
            .limit(1)
            .get();
        if (s.docs.isNotEmpty) {
          return TempSession(
            deliveryId: id,
            enteredByName: d[_K.enteredByName] as String?,
            enteredByEmail: (d[_K.enteredByEmail] as String?) ?? email,
            sources: ((d[_K.sources] as List?) ?? const [])
                .whereType<String>()
                .toList(),
            lastStoreId: lastStoreId,
            lastSource: lastSource,
          );
        }
      }

      // 2) Fallback: collectionGroup with SINGLE where, tenant check in-memory
      final cg = await _db
          .collectionGroup('batches')
          .where('deliveryId', isEqualTo: id) // single-field filter
          .limit(5)
          .get();

      final anyInTenant = cg.docs.any(
        (dd) => dd.reference.path.contains('tenants/$tenantId/stores/'),
      );

      if (anyInTenant) {
        return TempSession(
          deliveryId: id,
          enteredByName: d[_K.enteredByName] as String?,
          enteredByEmail: (d[_K.enteredByEmail] as String?) ?? email,
          sources: ((d[_K.sources] as List?) ?? const [])
              .whereType<String>()
              .toList(),
          lastStoreId: lastStoreId,
          lastSource: lastSource,
        );
      }
    }

    // No qualifying open sessions
    return null;
  }

  Future<void> upsertTemp({
    required String tenantId,
    required String deliveryId,
    required String enteredByEmail,
    required String enteredByName,
    required List<String> sources,
    String? lastStoreId, // ⬅️ new
    String? lastSource, // ⬅️ new
  }) async {
    final ref = _db
        .collection('tenants/$tenantId/${_K.collTemp}')
        .doc(deliveryId);

    await _db.runTransaction((txn) async {
      final snap = await txn.get(ref);
      if (!snap.exists) {
        txn.set(ref, {
          _K.deliveryId: deliveryId,
          _K.enteredByEmail: enteredByEmail.trim().toLowerCase(),
          _K.enteredByName: enteredByName,
          _K.sources: sources,
          _K.isFinalized: false,
          _K.batchesCount: 0,
          _K.startedAt: FieldValue.serverTimestamp(),
          _K.updatedAt: FieldValue.serverTimestamp(),
          _K.closedAt: null,
          _K.expiresAt: null,
          if (lastStoreId != null) _K.lastStoreId: lastStoreId,
          if (lastSource != null) _K.lastSource: lastSource,
        });
      } else {
        final prev = (snap.data()?[_K.sources] as List<dynamic>? ?? const [])
            .cast<String>();
        final merged = {...prev, ...sources}.toList();

        final data = <String, dynamic>{
          _K.enteredByEmail: enteredByEmail.trim().toLowerCase(),
          _K.enteredByName: enteredByName,
          _K.sources: merged,
          _K.isFinalized: false,
          _K.updatedAt: FieldValue.serverTimestamp(),
          _K.closedAt: null,
        };
        if (lastStoreId != null) data[_K.lastStoreId] = lastStoreId;
        if (lastSource != null) data[_K.lastSource] = lastSource;

        txn.set(ref, data, SetOptions(merge: true));
      }
    });
  }

  Future<void> updateLastPrefs({
    required String tenantId,
    required String deliveryId,
    String? lastStoreId,
    String? lastSource,
  }) async {
    final data = <String, dynamic>{};
    if (lastStoreId != null) data[_K.lastStoreId] = lastStoreId;
    if (lastSource != null) data[_K.lastSource] = lastSource;
    if (data.isEmpty) return;
    data[_K.updatedAt] = FieldValue.serverTimestamp();

    await _db
        .collection('tenants/$tenantId/${_K.collTemp}')
        .doc(deliveryId)
        .set(data, SetOptions(merge: true));
  }

  Future<void> finalizeTemp({
    required String tenantId,
    required String deliveryId,
    required int batchesCount,
  }) async {
    await _db
        .collection('tenants/$tenantId/${_K.collTemp}')
        .doc(deliveryId)
        .set({
          _K.isFinalized: true,
          _K.batchesCount: batchesCount,
          _K.finalizedAt: FieldValue.serverTimestamp(),
          _K.updatedAt: FieldValue.serverTimestamp(),
          _K.closedAt: FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  // ---------- Final save ----------
  Future<SaveResult> saveRecord({
    required String tenantId,
    required DeliveryRecord record,
  }) async {
    final ref = _db.doc(
      'tenants/$tenantId/${_K.collRecords}/${record.deliveryId}',
    );
    final existing = await ref.get();
    if (existing.exists) return SaveResult.alreadySaved;
    await ref.set(record.toMap(), SetOptions(merge: false));
    return SaveResult.saved;
  }

  // ---------- Local prefs ----------
  Future<void> persistLocal(DeliverySessionState state) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_K.prefsKey, jsonEncode(state.toJson()));
    } catch (e, st) {
      debugPrint('❌ persistLocal failed: $e\n$st');
    }
  }

  Future<DeliverySessionState?> restoreLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_K.prefsKey);
      if (raw == null) return null;
      return DeliverySessionState.fromJson(jsonDecode(raw));
    } catch (e, st) {
      debugPrint('❌ restoreLocal failed: $e\n$st');
      return null;
    }
  }

  Future<void> clearLocal() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_K.prefsKey);
    } catch (e, st) {
      debugPrint('❌ clearLocal failed: $e\n$st');
    }
  }

  // ---------- Review summary ----------
  Future<DeliveryReviewSummary?> buildReviewSummary({
    required WidgetRef ref,
    required String tenantId,
    required DeliverySessionState state,
  }) async {
    if (!state.isActive || state.deliveryId == null) return null;

    final batches = await ref.read(batchRecordsStreamProvider(tenantId).future);
    final linked = batches
        .where((b) => (b.deliveryId ?? '').trim() == state.deliveryId)
        .toList();
    if (linked.isEmpty) return null;

    final meds = await ref.read(medicationItemsStreamProvider(tenantId).future);
    final cons = await ref.read(consumableItemsStreamProvider(tenantId).future);
    final equip = await ref.read(equipmentItemsStreamProvider(tenantId).future);

    final srcs = linked
        .map((b) => b.source?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final record = DeliveryRecord.fromBatches(
      linked,
      state.deliveryId!,
      enteredByName: state.enteredByName ?? 'unknown',
      enteredByEmail: state.enteredByEmail ?? 'unknown',
      sources: srcs,
    );

    final items = linked
        .map(
          (b) => DeliveryReviewItem(
            name: resolveItemName(b, meds, cons, equip),
            quantity: b.quantity,
            store: b.storeId,
            type: b.itemType.name,
          ),
        )
        .toList();

    return DeliveryReviewSummary(summary: record, items: items);
  }

  String _2(int n) => n.toString().padLeft(2, '0');
}
