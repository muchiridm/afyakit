// lib/shared/providers/api_client_provider.dart

import 'package:afyakit/shared/providers/token_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/shared/api/api_client.dart';
import 'package:afyakit/tenants/providers/tenant_id_provider.dart';

final apiClientProvider = FutureProvider<ApiClient>((ref) async {
  final tenantId = ref.watch(tenantIdProvider);
  final tokenRepo = ref.watch(tokenProvider);

  return ApiClient.create(tenantId: tenantId, tokenProvider: tokenRepo);
});
