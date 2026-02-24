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

    // Wait for terminal STK result
    var p = await pollStatusUntilTerminal(
      paymentId: init.paymentId,
      timeout: timeout,
      firstDelay: firstDelay,
      interval: interval,
      onTick: onTick,
    );

    // If STK not success -> done
    if (!p.isSuccess) return p;

    // If STK success, Zoho sync may still be pending.
    // Wait briefly for zohoSyncStatus to hit success/failed.
    final deadline = DateTime.now().add(zohoSyncWaitMax);

    while (DateTime.now().isBefore(deadline)) {
      final z = (p.zohoSyncStatus ?? '').trim().toLowerCase();
      if (z == 'success' || z == 'failed') return p;

      await Future<void>.delayed(zohoSyncPollInterval);

      // re-fetch
      p = await getPaymentStatus(p.id);
      onTick?.call(p);
    }

    return p;
  }
}

/// ✅ Provider (matches your existing pattern)
final mpesaServiceProvider = FutureProvider<MpesaService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);

  final client = await ref.watch(afyakitClientFutureProvider.future);
  return MpesaService(client, routes);
});
