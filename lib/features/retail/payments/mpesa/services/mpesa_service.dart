// lib/features/retail/payments/mpesa/services/mpesa_service.dart

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';

import '../models/mpesa_stk_draft.dart';
import '../models/mpesa_payment.dart';
import '../models/mpesa_responses.dart';

class MpesaService {
  MpesaService(this._client, this._routes);

  final AfyaKitClient _client;
  final AfyaKitRoutes _routes;

  Future<MpesaPayment> initiateStk(MpesaStkInitiateDraft draft) async {
    final uri = _routes.mpesaStkInitiate();

    final res = await _client.postUri<JsonMap>(uri, data: draft.toJson());
    final data = res.data ?? const <String, dynamic>{};

    return MpesaInitiateResponse.fromJson(data).payment;
  }

  Future<MpesaPayment> getPaymentStatus(String paymentId) async {
    final uri = _routes.mpesaPaymentStatus(paymentId);

    final res = await _client.getUri<JsonMap>(uri);
    final data = res.data ?? const <String, dynamic>{};

    return MpesaStatusResponse.fromJson(data).payment;
  }
}

/// ✅ Provider (matches your existing pattern)
final mpesaServiceProvider = FutureProvider<MpesaService>((ref) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);

  final client = await ref.watch(afyakitClientFutureProvider.future);
  return MpesaService(client, routes);
});
