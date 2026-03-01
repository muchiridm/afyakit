// lib/features/retail/payments/mpesa/services/mpesa_service.dart

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/shared/utils/utils.dart';

import '../models/mpesa_payment.dart';
import '../models/mpesa_responses.dart';
import '../models/mpesa_stk_draft.dart';

typedef MpesaTick = void Function(MpesaPayment payment);

class MpesaService {
  MpesaService(this._client, this._routes);

  final AfyaKitClient _client;
  final AfyaKitRoutes _routes;

  // ─────────────────────────────────────────────
  // API calls
  // ─────────────────────────────────────────────

  Future<MpesaInitiateResult> initiateStk(MpesaStkInitiateDraft draft) async {
    final uri = _routes.mpesaStkInitiate();

    final res = await _client.postUri<JsonMap>(uri, data: draft.toJson());
    final data = res.data ?? const <String, dynamic>{};

    return MpesaInitiateResult.fromJson(data);
  }

  Future<MpesaPayment> getPaymentStatus(String paymentId) async {
    final uri = _routes.mpesaPaymentStatus(paymentId);

    final res = await _client.getUri<JsonMap>(uri);
    final data = res.data ?? const <String, dynamic>{};

    return MpesaStatusResponse.fromJson(data).payment;
  }

  // ─────────────────────────────────────────────
  // Polling
  // ─────────────────────────────────────────────

  /// Poll GET /payments/:paymentId until terminal (stk_success|stk_failed)
  /// or timeout, returning the latest known status.
  Future<MpesaPayment> pollStatusUntilTerminal({
    required String paymentId,
    Duration timeout = const Duration(minutes: 2),
    Duration firstDelay = const Duration(milliseconds: 1200),
    Duration interval = const Duration(seconds: 2),
    MpesaTick? onTick,
  }) async {
    final deadline = DateTime.now().add(timeout);

    // Small initial delay so callback can land
    await Future<void>.delayed(firstDelay);

    while (true) {
      final p = await getPaymentStatus(paymentId);
      onTick?.call(p);

      if (p.isTerminal) return p;

      if (DateTime.now().isAfter(deadline)) {
        // timeout -> return latest status we saw
        return p;
      }

      await Future<void>.delayed(interval);
    }
  }

  /// Convenience: initiate STK then wait for terminal result.
  ///
  /// After terminal STK, we optionally wait a short time for Zoho sync
  /// to become success/failed (trigger is async).
  Future<MpesaPayment> initiateAndWait({
    required MpesaStkInitiateDraft draft,
    Duration timeout = const Duration(minutes: 2),
    Duration firstDelay = const Duration(milliseconds: 1200),
    Duration interval = const Duration(seconds: 2),
    Duration zohoSyncWaitMax = const Duration(seconds: 25),
    Duration zohoSyncPollInterval = const Duration(seconds: 2),
    MpesaTick? onTick,
  }) async {
    final init = await initiateStk(draft);

    // 1) Wait only for terminal STK (success/failed).
    final terminal = await pollStatusUntilTerminal(
      paymentId: init.paymentId,
      timeout: timeout,
      firstDelay: firstDelay,
      interval: interval,
      onTick: onTick,
    );

    // Always emit terminal tick
    onTick?.call(terminal);

    // 2) Return immediately once STK is terminal.
    //    Zoho sync is secondary and MUST NOT block.
    if (!terminal.isSuccess) return terminal;

    // 3) Optional: fire-and-forget short Zoho sync watcher for UI niceness.
    //    This updates UI via onTick but does not block the returned result.
    // ignore: discarded_futures
    _watchZohoSyncNonBlocking(
      paymentId: terminal.id,
      onTick: onTick,
      maxWait: zohoSyncWaitMax,
      interval: zohoSyncPollInterval,
    );

    return terminal;
  }

  Future<void> _watchZohoSyncNonBlocking({
    required String paymentId,
    required MpesaTick? onTick,
    required Duration maxWait,
    required Duration interval,
  }) async {
    if (onTick == null) return;

    final deadline = DateTime.now().add(maxWait);

    while (DateTime.now().isBefore(deadline)) {
      final p = await getPaymentStatus(paymentId);
      onTick(p);

      final z = (p.zohoSyncStatus ?? '').trim().toLowerCase();
      if (z == 'success' || z == 'failed') return;

      await Future<void>.delayed(interval);
    }
  }
}

/// ✅ Provider (matches your existing pattern)
final mpesaServiceProvider = FutureProvider<MpesaService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);

  final client = await ref.watch(afyakitClientFutureProvider.future);
  return MpesaService(client, routes);
});
