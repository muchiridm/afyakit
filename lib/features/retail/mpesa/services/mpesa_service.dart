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

  Future<MpesaInitiateResult> initiateStk(MpesaStkInitiateDraft draft) async {
    final uri = _routes.retailMpesaStkInitiate();

    final res = await _client.postUri<JsonMap>(uri, data: draft.toJson());
    final data = res.data ?? const <String, dynamic>{};

    return MpesaInitiateResult.fromJson(data);
  }

  Future<MpesaPayment> getPaymentStatus(String paymentId) async {
    final uri = _routes.retailMpesaPaymentStatus(paymentId);

    final res = await _client.getUri<JsonMap>(uri);
    final data = res.data ?? const <String, dynamic>{};

    return MpesaStatusResponse.fromJson(data).payment;
  }

  Future<MpesaPayment> pollStatusUntilTerminal({
    required String paymentId,
    Duration timeout = const Duration(minutes: 2),
    Duration firstDelay = const Duration(milliseconds: 1200),
    Duration interval = const Duration(seconds: 2),
    MpesaTick? onTick,
  }) async {
    final deadline = DateTime.now().add(timeout);

    await Future<void>.delayed(firstDelay);

    while (true) {
      final p = await getPaymentStatus(paymentId);
      onTick?.call(p);

      if (p.isTerminal) return p;

      if (DateTime.now().isAfter(deadline)) {
        return p;
      }

      await Future<void>.delayed(interval);
    }
  }

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

    final terminal = await pollStatusUntilTerminal(
      paymentId: init.paymentId,
      timeout: timeout,
      firstDelay: firstDelay,
      interval: interval,
      onTick: onTick,
    );

    onTick?.call(terminal);

    if (!terminal.isSuccess) return terminal;

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

final mpesaServiceProvider = FutureProvider<MpesaService>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);

  final client = await ref.watch(afyakitClientFutureProvider.future);
  return MpesaService(client, routes);
});
