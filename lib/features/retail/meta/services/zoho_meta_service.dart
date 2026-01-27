import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

import '../../shared/models/zoho_account.dart';

typedef JsonMap = Map<String, dynamic>;

final zohoMetaServiceProvider = FutureProvider<ZohoMetaService>((ref) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientProvider.future);
  return ZohoMetaService(api: api, routes: routes);
});

class ZohoMetaService {
  ZohoMetaService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<ZohoAccount>> listAccounts({
    String? search,
    String? type,
    bool? active,
  }) async {
    final uri = routes.zohoMetaAccounts(
      search: search,
      type: type,
      active: active,
    );
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['accounts'] ?? data['items'] ?? data['data'];

    if (raw is List) {
      return raw
          .whereType<Map>()
          .map((m) => ZohoAccount.fromJson(m.cast<String, dynamic>()))
          .where((a) => a.accountId.trim().isNotEmpty)
          .toList(growable: false);
    }

    return const <ZohoAccount>[];
  }

  Future<ZohoAccount> getAccount(String accountId) async {
    final id = accountId.trim();
    if (id.isEmpty) throw ArgumentError('accountId is empty');

    final uri = routes.zohoMetaAccountById(id);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['account'] ?? data;

    if (raw is Map<String, dynamic>) return ZohoAccount.fromJson(raw);
    if (raw is Map) return ZohoAccount.fromJson(raw.cast<String, dynamic>());

    throw StateError('Unexpected response shape: missing account object');
  }

  static JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
