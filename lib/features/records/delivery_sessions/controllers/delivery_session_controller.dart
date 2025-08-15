import 'dart:async';
import 'package:afyakit/shared/providers/stock/batch_records_stream_provider.dart';
import 'package:afyakit/users/providers/current_user_provider.dart';
import 'package:afyakit/shared/utils/firestore_instance.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/tenants/providers/tenant_id_provider.dart';
import 'package:afyakit/features/records/delivery_sessions/models/delivery_record.dart';
import 'package:afyakit/features/records/delivery_sessions/controllers/delivery_session_state.dart';
import 'package:afyakit/features/records/delivery_sessions/services/delivery_review_service.dart';
import 'package:afyakit/features/records/delivery_sessions/services/delivery_persistence_service.dart';
import 'package:afyakit/features/records/delivery_sessions/services/delivery_session_service.dart';
import 'package:afyakit/features/records/delivery_sessions/models/view_models/delivery_review_summary.dart';

final deliverySessionControllerProvider =
    StateNotifierProvider.autoDispose<
      DeliverySessionController,
      DeliverySessionState
    >((ref) => DeliverySessionController(ref));

class DeliverySessionController extends StateNotifier<DeliverySessionState> {
  final Ref ref;
  final DeliverySessionService _deliveryService;

  DeliverySessionController(this.ref)
    : _deliveryService = DeliverySessionService(),
      super(const DeliverySessionState()) {
    _restoreSession();
  }

  // ─────────────────────────────────────────────
  // 🚀 Session Lifecycle
  // ─────────────────────────────────────────────
  Future<void> ensureActiveSession({
    required String enteredByName,
    required String enteredByEmail,
    required String source,
    String? storeId,
  }) async {
    final tenantId = ref.read(tenantIdProvider);

    if (!state.isActive) {
      // 🔎 Try resuming an open temp session for this user (handles midnight)
      final open = await _deliveryService.findOpenSession(
        tenantId: tenantId,
        enteredByEmail: enteredByEmail,
      );

      if (open != null) {
        resume(
          open.deliveryId,
          enteredByName: open.enteredByName ?? enteredByName,
          enteredByEmail: enteredByEmail,
          sources: open.sources.isEmpty ? [source] : open.sources,
        );
      } else {
        await startNew(
          enteredByName: enteredByName,
          enteredByEmail: enteredByEmail,
          sources: [source],
        );
      }
    } else if (!state.sources.contains(source)) {
      addSource(source);
    }

    // 📝 Remember last used values
    state = state.copyWith(
      lastSource: source,
      lastStoreId: storeId ?? state.lastStoreId,
    );

    // ♻️ Keep temp doc fresh
    await _deliveryService.upsertTempSession(
      tenantId: tenantId,
      deliveryId: state.deliveryId!,
      enteredByEmail: enteredByEmail,
      enteredByName: enteredByName,
      sources: state.sources,
    );

    await DeliveryPersistenceService.persistAll(tenantId, state);
  }

  Future<void> startNew({
    required String enteredByName,
    required String enteredByEmail,
    required List<String> sources,
  }) async {
    final tenantId = ref.read(tenantIdProvider);
    final deliveryId = await generatePersistentDeliveryId(tenantId);

    final newState = DeliverySessionState(
      deliveryId: deliveryId,
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      sources: sources.toSet().toList(),
    );

    state = newState;

    await DeliveryPersistenceService.persistAll(tenantId, newState);
    await _deliveryService.upsertTempSession(
      tenantId: tenantId,
      deliveryId: deliveryId,
      enteredByEmail: enteredByEmail,
      enteredByName: enteredByName,
      sources: newState.sources,
    );

    debugPrint('📦 New delivery session started → $deliveryId');
  }

  void resume(
    String deliveryId, {
    String? enteredByName,
    String? enteredByEmail,
    List<String>? sources,
  }) {
    final resumedState = DeliverySessionState(
      deliveryId: deliveryId,
      enteredByName: enteredByName,
      enteredByEmail: enteredByEmail,
      sources: sources?.toSet().toList() ?? [],
    );

    state = resumedState;
    final tenantId = ref.read(tenantIdProvider);
    DeliveryPersistenceService.persistAll(tenantId, resumedState);
  }

  void addSource(String source) {
    if (!state.sources.contains(source)) {
      final updatedSources = [...state.sources, source.trim()];
      state = state.copyWith(sources: updatedSources);

      final tenantId = ref.read(tenantIdProvider);
      DeliveryPersistenceService.persistAll(tenantId, state);
    }
  }

  Future<void> _restoreSession() async {
    final tenantId = ref.read(tenantIdProvider);

    // 1) Try local cache first (fast path)
    final local = await DeliveryPersistenceService.restoreState(tenantId);
    if (local != null && local.isActive) {
      state = local;
      debugPrint('♻️ Session restored (local) → ${local.deliveryId}');
      return;
    }

    // 2) If no local, try Firestore temp sessions for this signed-in user
    try {
      // Wait for user session to be available
      final user = await ref.read(currentUserFutureProvider.future);
      final email = (user?.email ?? '').trim().toLowerCase();

      if (email.isEmpty) {
        debugPrint('📭 No cached session and no user email yet.');
        return;
      }

      final open = await _deliveryService.findOpenSession(
        tenantId: tenantId,
        enteredByEmail: email,
      );

      if (open != null) {
        // Rehydrate controller state from the temp doc
        resume(
          open.deliveryId,
          enteredByName: open.enteredByName,
          enteredByEmail: open.enteredByEmail,
          sources: open.sources,
        );
        // Persist locally so future startups are instant
        await DeliveryPersistenceService.persistAll(tenantId, state);
        debugPrint('🔄 Session restored (firestore) → ${open.deliveryId}');
      } else {
        debugPrint('📭 No cached or open delivery session found.');
      }
    } catch (e, st) {
      debugPrint('❌ _restoreSession failed: $e\n$st');
    }
  }

  // ─────────────────────────────────────────────
  // 📦 Session Completion
  // ─────────────────────────────────────────────
  Future<bool> endDeliverySession({bool autoRestart = false}) async {
    final tenantId = ref.read(tenantIdProvider);
    final batches = await ref.read(batchRecordsStreamProvider(tenantId).future);

    final sessionBatches = batches
        .where((b) => b.deliveryId == state.deliveryId)
        .toList();

    final extractedSources = sessionBatches
        .map((b) => b.source?.trim())
        .whereType<String>()
        .where((s) => s.isNotEmpty)
        .toSet()
        .toList();

    final sources = state.sources.isNotEmpty ? state.sources : extractedSources;

    final isValid =
        state.deliveryId?.isNotEmpty == true &&
        state.enteredByName?.isNotEmpty == true &&
        state.enteredByEmail?.isNotEmpty == true &&
        sources.isNotEmpty &&
        sessionBatches.isNotEmpty &&
        tenantId.isNotEmpty;

    if (!isValid) {
      debugPrint('⚠️ Incomplete session. Aborting save.');
      return false;
    }

    try {
      final record = DeliveryRecord.fromBatches(
        sessionBatches,
        state.deliveryId!,
        enteredByName: state.enteredByName!,
        enteredByEmail: state.enteredByEmail!,
        sources: sources,
      );

      // ⬇️ Idempotent save: both "saved" and "alreadySaved" are OK
      final result = await _deliveryService.saveDeliverySession(
        tenantId: tenantId,
        record: record,
      );

      // ✅ Always finalize the temp doc (even if it already existed)
      await _deliveryService.finalizeTempSession(
        tenantId: tenantId,
        deliveryId: state.deliveryId!,
        batchesCount: sessionBatches.length,
      );

      // 🧹 Clear local persistence and reset state
      await DeliveryPersistenceService.clearAll(tenantId, state.deliveryId!);

      final enteredByName = state.enteredByName!;
      final enteredByEmail = state.enteredByEmail!;
      state = const DeliverySessionState();

      if (autoRestart) {
        await startNew(
          enteredByName: enteredByName,
          enteredByEmail: enteredByEmail,
          sources: const [],
        );
      }

      return result == SaveResult.saved || result == SaveResult.alreadySaved;
    } catch (e, st) {
      debugPrint('❌ Failed to save delivery session: $e\n$st');
      return false;
    }
  }

  // ─────────────────────────────────────────────
  // 🧾 Review Summary
  // ─────────────────────────────────────────────
  Future<DeliveryReviewSummary?> getReviewSummary({
    required String tenantId,
    required DeliverySessionState state,
    required WidgetRef ref,
  }) async {
    return getDeliveryReviewSummary(tenantId: tenantId, state: state, ref: ref);
  }

  // ─────────────────────────────────────────────
  // 🔧 ID Generator
  // ─────────────────────────────────────────────
  Future<String> generatePersistentDeliveryId(String tenantId) async {
    final now = DateTime.now();
    final dateKey = '${now.year}${_twoDigits(now.month)}${_twoDigits(now.day)}';
    final docRef = db
        .collection('tenants')
        .doc(tenantId)
        .collection('delivery_id_counters')
        .doc(dateKey);

    final result = await db.runTransaction((txn) async {
      final snapshot = await txn.get(docRef);
      final current = snapshot.exists ? (snapshot.data()?['count'] ?? 0) : 0;
      final next = current + 1;
      txn.set(docRef, {'count': next}, SetOptions(merge: true));
      return next;
    });

    return 'DN_${dateKey}_${result.toString().padLeft(3, '0')}';
  }

  String _twoDigits(int n) => n.toString().padLeft(2, '0');
}
