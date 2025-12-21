// lib/core/records/deliveries/controllers/delivery_session_engine.dart

import 'package:afyakit/core/auth_user/models/auth_user_model.dart';
import 'package:afyakit/core/auth_user/providers/current_user_providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/modules/inventory/batches/providers/batch_records_stream_provider.dart';

import 'package:afyakit/modules/inventory/records/deliveries/controllers/delivery_session_state.dart';
import 'package:afyakit/modules/inventory/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/modules/inventory/records/deliveries/models/delivery_review_summary.dart';
import 'package:afyakit/modules/inventory/records/deliveries/services/delivery_session_service.dart';

/// Engine: holds state + logic. Single source of truth for delivery sessions.
final deliverySessionEngineProvider =
    StateNotifierProvider.autoDispose<
      DeliverySessionEngine,
      DeliverySessionState
    >((ref) {
      // Keep the engine alive briefly after last listener disappears to avoid flapping.
      final link = ref.keepAlive();
      ref.onCancel(() {
        Future.delayed(const Duration(seconds: 10), link.close);
      });
      return DeliverySessionEngine(ref, DeliverySessionService());
    });

class DeliverySessionEngine extends StateNotifier<DeliverySessionState> {
  final Ref ref;
  final DeliverySessionService svc;

  DeliverySessionEngine(this.ref, this.svc)
    : super(const DeliverySessionState()) {
    _restore();

    // Re-run restore when the session user resolves/changes.
    ref.listen<AsyncValue<AuthUser?>>(currentUserProvider, (prev, next) async {
      final user = next.valueOrNull;
      if (!mounted || user == null) return;

      if (!state.isActive) {
        debugPrint('🔁 [DSE] user resolved → re-restoring session…');
        await _restore();
      }
    });
  }

  // ── keepAlive for async ops ──────────────────────────────────
  Future<T> _withKeepAlive<T>(Future<T> Function() body) async {
    final link = ref.keepAlive();
    try {
      return await body();
    } finally {
      link.close();
    }
  }

  // ── safe state setters ───────────────────────────────────────
  void _safeSet(DeliverySessionState next) {
    if (!mounted) {
      if (kDebugMode) debugPrint('🛑 [DSE] set skipped (unmounted)');
      return;
    }
    state = next;
  }

  void _safeUpdate(DeliverySessionState Function(DeliverySessionState) fn) {
    if (!mounted) {
      if (kDebugMode) debugPrint('🛑 [DSE] update skipped (unmounted)');
      return;
    }
    state = fn(state);
  }

  // ─────────────────────────────────────────────────────────────
  // Public API
  // NOTE: `enteredByEmail` now carries the WhatsApp number (E.164)
  // ─────────────────────────────────────────────────────────────

  Future<void> ensureActive({
    required String enteredByName,
    required String enteredByEmail, // ← WA number
    required String source,
    String? storeId,
  }) => _withKeepAlive(() async {
    final tenantId = ref.read(tenantSlugProvider);
    final cleanSrc = source.trim();
    final cleanStore = (storeId ?? '').trim();

    if (!state.isActive) {
      final open = await svc.findOpen(
        tenantId: tenantId,
        enteredByEmail: enteredByEmail,
      );
      if (!mounted) return;

      if (open != null) {
        _safeSet(
          DeliverySessionState(
            deliveryId: open.deliveryId,
            enteredByName: _resolveName(
              open.enteredByName,
              enteredByName,
              enteredByEmail,
            ),
            enteredByEmail: open.enteredByEmail,
            sources: _dedup([
              ...open.sources,
              if (cleanSrc.isNotEmpty) cleanSrc,
            ]),
            // prefer provided context, otherwise carry what was in temp
            lastStoreId: cleanStore.isNotEmpty ? cleanStore : open.lastStoreId,
            lastSource: cleanSrc.isNotEmpty ? cleanSrc : open.lastSource,
          ),
        );
        debugPrint('🔄 Resumed delivery → ${state.deliveryId}');
      } else {
        final id = await svc.newDeliveryId(tenantId);
        if (!mounted) return;
        _safeSet(
          DeliverySessionState(
            deliveryId: id,
            enteredByName: _resolveName(null, enteredByName, enteredByEmail),
            enteredByEmail: enteredByEmail,
            sources: cleanSrc.isEmpty ? const [] : [cleanSrc],
            lastStoreId: cleanStore.isNotEmpty ? cleanStore : null,
            lastSource: cleanSrc.isNotEmpty ? cleanSrc : null,
          ),
        );
        debugPrint('📦 Started new delivery → $id');
      }
    } else {
      if (cleanSrc.isNotEmpty && !state.sources.contains(cleanSrc)) {
        _safeUpdate(
          (s) => s.copyWith(sources: _dedup([...s.sources, cleanSrc])),
        );
      }
      _safeUpdate(
        (s) => s.copyWith(
          lastStoreId: cleanStore.isNotEmpty ? cleanStore : s.lastStoreId,
          lastSource: cleanSrc.isNotEmpty ? cleanSrc : s.lastSource,
          enteredByName: _resolveName(
            s.enteredByName,
            enteredByName,
            enteredByEmail,
          ),
        ),
      );
    }

    // persist temp & local (now always carrying latest context)
    final id = state.deliveryId;
    if (id != null && id.isNotEmpty) {
      await svc.upsertTemp(
        tenantId: tenantId,
        deliveryId: id,
        enteredByEmail: enteredByEmail,
        enteredByName: state.enteredByName ?? enteredByEmail,
        sources: state.sources,
        lastStoreId: state.lastStoreId,
        lastSource: state.lastSource,
      );
    }
    if (mounted) await svc.persistLocal(state);
  });

  Future<void> addSource(String source) => _withKeepAlive(() async {
    final s = source.trim();
    if (s.isEmpty || state.sources.contains(s)) return;
    _safeUpdate((st) => st.copyWith(sources: _dedup([...st.sources, s])));
    if (mounted) await svc.persistLocal(state);
  });

  Future<DeliveryReviewSummary?> review(WidgetRef widgetRef) async {
    final tenantId = ref.read(tenantSlugProvider);
    return svc.buildReviewSummary(
      ref: widgetRef,
      tenantId: tenantId,
      state: state,
    );
  }

  Future<bool> end({bool autoRestart = false}) => _withKeepAlive(() async {
    if (!mounted) return false;

    final tenantId = ref.read(tenantSlugProvider);
    final batches = await ref.read(batchRecordsStreamProvider(tenantId).future);
    if (!mounted) return false;

    final linked = batches
        .where((b) => (b.deliveryId ?? '').trim() == (state.deliveryId ?? ''))
        .toList();

    final mergedSources = _dedup([
      ...state.sources,
      ...linked.map((b) => (b.source ?? '').trim()),
    ]);

    final valid =
        (state.deliveryId ?? '').isNotEmpty &&
        (state.enteredByEmail ?? '').isNotEmpty &&
        mergedSources.isNotEmpty &&
        linked.isNotEmpty &&
        tenantId.isNotEmpty;

    if (!valid) {
      debugPrint(
        '⚠️ Incomplete delivery; aborting save. '
        'deliveryId=${state.deliveryId} linked=${linked.length} '
        'sources=${mergedSources.length} contact=${state.enteredByEmail?.isNotEmpty == true}',
      );
      return false;
    }

    final resolvedName = _resolveName(
      state.enteredByName,
      null,
      state.enteredByEmail!,
    );

    final record = DeliveryRecord.fromBatches(
      linked,
      state.deliveryId!,
      enteredByName: resolvedName,
      enteredByEmail: state.enteredByEmail!, // WA number
      sources: mergedSources,
    );

    final result = await svc.saveRecord(tenantId: tenantId, record: record);
    if (!mounted) return false;

    await svc.finalizeTemp(
      tenantId: tenantId,
      deliveryId: state.deliveryId!,
      batchesCount: linked.length,
    );
    if (!mounted) return false;

    await svc.clearLocal();

    final name = state.enteredByName;
    final contact = state.enteredByEmail;
    _safeSet(const DeliverySessionState());

    if (autoRestart && contact != null) {
      await ensureActive(
        enteredByName: _resolveName(name, null, contact),
        enteredByEmail: contact,
        source: '',
      );
    }

    return result == SaveResult.saved || result == SaveResult.alreadySaved;
  });

  Future<void> rememberLastUsed({String? lastStoreId, String? lastSource}) =>
      _withKeepAlive(() async {
        if (!mounted || !state.isActive) return;
        final tenantId = ref.read(tenantSlugProvider);

        final newLastStore = (lastStoreId ?? '').trim();
        final newLastSource = (lastSource ?? '').trim();

        _safeUpdate(
          (s) => s.copyWith(
            lastStoreId: newLastStore.isNotEmpty ? newLastStore : s.lastStoreId,
            lastSource: newLastSource.isNotEmpty ? newLastSource : s.lastSource,
          ),
        );

        if (!mounted) return;
        await svc.updateLastPrefs(
          tenantId: tenantId,
          deliveryId: state.deliveryId!,
          lastStoreId: newLastStore.isNotEmpty ? newLastStore : null,
          lastSource: newLastSource.isNotEmpty ? newLastSource : null,
        );
      });

  // ─────────────────────────────────────────────────────────────
  // Internals
  // ─────────────────────────────────────────────────────────────

  Future<void> _restore() => _withKeepAlive(() async {
    final tenantId = ref.read(tenantSlugProvider);

    // 1) Try local cache first
    final local = await svc.restoreLocal();
    if (!mounted) return;

    if (local != null && local.isActive) {
      _safeSet(local);
      debugPrint('♻️ Session restored (local) → ${local.deliveryId}');
      return;
    }

    // 2) Fallback to server-side open session, keyed by WA number
    try {
      // Use the session-backed snapshot instead of refetching
      final user = ref.read(currentUserValueProvider);
      if (!mounted) return;

      final waNumber = (user?.phoneNumber ?? '').trim();
      final displayName = (user?.displayName ?? '').trim();

      if (waNumber.isEmpty) {
        debugPrint(
          '📭 _restore: no WA number available, skipping server restore',
        );
        return;
      }

      final open = await svc.findOpen(
        tenantId: tenantId,
        enteredByEmail: waNumber, // WA number used as key
      );
      if (!mounted) return;

      if (open != null) {
        _safeUpdate(
          (s) => s.copyWith(
            deliveryId: open.deliveryId,
            enteredByName: _resolveName(
              open.enteredByName,
              displayName,
              waNumber,
            ),
            enteredByEmail: open.enteredByEmail,
            sources: _dedup(open.sources),
            lastStoreId: open.lastStoreId,
            lastSource: open.lastSource,
          ),
        );

        if (mounted) {
          await svc.persistLocal(state);
          debugPrint('🔄 Session restored (firestore) → ${open.deliveryId}');
        }
      } else {
        debugPrint('📭 No cached or open delivery session found.');
      }
    } catch (e, st) {
      debugPrint('❌ _restore failed: $e\n$st');
    }
  });

  List<String> _dedup(List<String> src) =>
      src.map((e) => e.trim()).where((e) => e.isNotEmpty).toSet().toList();

  String _resolveName(
    String? candidate,
    String? fallbackName,
    String contactId,
  ) {
    final c = (candidate ?? '').trim();
    if (c.isNotEmpty) return c;
    final f = (fallbackName ?? '').trim();
    if (f.isNotEmpty) return f;
    return contactId.trim();
  }
}
