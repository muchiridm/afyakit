import 'package:afyakit/hq/tenants/providers/tenant_providers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:afyakit/api/dawaindex/config.dart';
import 'package:afyakit/api/dawaindex/client.dart';

final diApiConfigProvider = Provider<DiApiConfig>((ref) {
  final tenantId = ref.watch(tenantSlugProvider);
  final cfg = resolveDiApiBaseForTenant(tenantId);
  if (kDebugMode) {
    debugPrint(
      '🔧 diApiConfig → base=${cfg.baseUrl} key=${(cfg.apiKey ?? '').isNotEmpty ? 'set' : 'empty'}',
    );
  }
  return cfg;
});

final dawaIndexClientProvider = FutureProvider<DawaIndexClient>((ref) async {
  final cfg = ref.watch(diApiConfigProvider);
  return DawaIndexClient.create(baseUrl: cfg.baseUrl, apiKey: cfg.apiKey);
});

@Deprecated('Use dawaIndexClientProvider instead.')
final diApiClientProvider = dawaIndexClientProvider;
