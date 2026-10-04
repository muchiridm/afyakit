// lib/features/inventory/records/deliveries/controllers/delivery_session_engine.dart

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

import 'package:afyakit/features/inventory/records/deliveries/controllers/delivery_session_state.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_record.dart';
import 'package:afyakit/features/inventory/records/deliveries/models/delivery_review_summary.dart';
import 'package:afyakit/features/inventory/records/deliveries/services/delivery_session_service.dart';

final deliverySessionEngineProvider =
    StateNotifierProvider.autoDispose<
      DeliverySessionEngine,
      DeliverySessionState
    >((ref) {
      final link = ref.keepAlive();

      ref.onCancel(() {
        Future.delayed(const Duration(seconds: 10), link.close);
      });

      final service = ref.read(deliverySessionServiceProvider);

      return DeliverySessionEngine(ref, service);
    });

class DeliverySessionEngine extends StateNotifier<DeliverySessionState> {
  DeliverySessionEngine(this.ref, this.svc)
    : super(const DeliverySessionState()) {
    _restore();
  }

  final Ref ref;
  final DeliverySessionService svc;

  // ─────────────────────────────────────────────
  // Keep alive for async operations
  // ─────────────────────────────────────────────

  Future<T> _withKeepAlive<T>(Future<T> Function() body) async {
    final link = ref.keepAlive();

    try {
      return await body();
    } finally {
      link.close();
    }
  }

  void _safeSet(DeliverySessionState next) {
    if (!mounted) {
      if (kDebugMode) {
        debugPrint(
          '🛑 [DSE] state update skipped '
          '(unmounted)',
        );
      }

      return;
    }

    state = next;
  }

  // ─────────────────────────────────────────────
  // Ensure / resume session
  // ─────────────────────────────────────────────

  Future<void> ensureActive({
    String? enteredByName,
    String? enteredByEmail,
    required String source,
    String? storeId,
  }) => _withKeepAlive(() async {
    final tenantId = ref.read(tenantIdProvider);

    final session = await svc.ensureSession(
      tenantId: tenantId,
      source: source,
      storeId: storeId,
    );

    if (!mounted) {
      return;
    }

    _safeSet(session);

    await svc.persistLocal(session);

    if (kDebugMode) {
      debugPrint(
        '📦 Delivery active → '
        '${session.deliveryId}',
      );
    }
  });

  // ─────────────────────────────────────────────
  // Source/context updates
  // ─────────────────────────────────────────────

  Future<void> addSource(String source) => _withKeepAlive(() async {
    final cleanSource = source.trim();

    final deliveryId = state.deliveryId?.trim() ?? '';

    if (cleanSource.isEmpty || deliveryId.isEmpty) {
      return;
    }

    final tenantId = ref.read(tenantIdProvider);

    final updated = await svc.updateSession(
      tenantId: tenantId,
      deliveryId: deliveryId,
      source: cleanSource,
    );

    if (!mounted) {
      return;
    }

    _safeSet(updated);

    await svc.persistLocal(updated);
  });

  Future<void> rememberLastUsed({String? lastStoreId, String? lastSource}) =>
      _withKeepAlive(() async {
        final deliveryId = state.deliveryId?.trim() ?? '';

        if (deliveryId.isEmpty) {
          return;
        }

        final cleanStore = lastStoreId?.trim();

        final cleanSource = lastSource?.trim();

        if ((cleanStore == null || cleanStore.isEmpty) &&
            (cleanSource == null || cleanSource.isEmpty)) {
          return;
        }

        final tenantId = ref.read(tenantIdProvider);

        final updated = await svc.updateSession(
          tenantId: tenantId,
          deliveryId: deliveryId,
          storeId: cleanStore?.isNotEmpty == true ? cleanStore : null,
          source: cleanSource?.isNotEmpty == true ? cleanSource : null,
        );

        if (!mounted) {
          return;
        }

        _safeSet(updated);

        await svc.persistLocal(updated);
      });

  // ─────────────────────────────────────────────
  // Review
  // ─────────────────────────────────────────────

  Future<DeliveryReviewSummary?> review([WidgetRef? _]) async {
    final deliveryId = state.deliveryId?.trim() ?? '';

    if (deliveryId.isEmpty) {
      return null;
    }

    final tenantId = ref.read(tenantIdProvider);

    return svc.reviewSession(tenantId: tenantId, deliveryId: deliveryId);
  }

  // ─────────────────────────────────────────────
  // Finalize
  // ─────────────────────────────────────────────

  Future<bool> end({bool autoRestart = false}) => _withKeepAlive(() async {
    final deliveryId = state.deliveryId?.trim() ?? '';

    if (deliveryId.isEmpty) {
      return false;
    }

    final tenantId = ref.read(tenantIdProvider);

    final previousSource = state.lastSource;

    final previousStore = state.lastStoreId;

    final DeliveryRecord record;

    try {
      record = await svc.finalizeSession(
        tenantId: tenantId,
        deliveryId: deliveryId,
      );
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '❌ Delivery finalize failed: '
          '$e\n$st',
        );
      }

      return false;
    }

    if (!mounted) {
      return false;
    }

    await svc.clearLocal();

    _safeSet(const DeliverySessionState());

    if (kDebugMode) {
      debugPrint(
        '✅ Delivery finalized → '
        '${record.deliveryId}',
      );
    }

    if (autoRestart) {
      final source = previousSource?.trim() ?? '';

      final store = previousStore?.trim();

      await ensureActive(
        source: source,
        storeId: store?.isNotEmpty == true ? store : null,
      );
    }

    return true;
  });

  // ─────────────────────────────────────────────
  // Restore
  // ─────────────────────────────────────────────

  Future<void> _restore() => _withKeepAlive(() async {
    final tenantId = ref.read(tenantIdProvider);

    try {
      // Local state is only a UX hint.
      final local = await svc.restoreLocal();

      if (!mounted) {
        return;
      }

      // Backend remains authoritative.
      final open = await svc.getOpenSession(tenantId);

      if (!mounted) {
        return;
      }

      if (open != null) {
        _safeSet(open);

        await svc.persistLocal(open);

        if (kDebugMode) {
          debugPrint(
            '🔄 Delivery restored '
            'from API → '
            '${open.deliveryId}',
          );
        }

        return;
      }

      // Backend says there is no open session.
      // Do not resurrect stale local state.
      if (local != null) {
        await svc.clearLocal();
      }

      _safeSet(const DeliverySessionState());

      if (kDebugMode) {
        debugPrint('📭 No open delivery session.');
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint(
          '❌ Delivery restore failed: '
          '$e\n$st',
        );
      }
    }
  });
}
