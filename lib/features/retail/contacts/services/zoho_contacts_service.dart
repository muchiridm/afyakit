// lib/features/retail/contacts/services/zoho_contacts_service.dart

import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

typedef JsonMap = Map<String, dynamic>;

final zohoContactsServiceProvider = FutureProvider<ZohoContactsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);

  // ✅ afyakitClientProvider is a FutureProvider, so await it
  final api = await ref.watch(afyakitClientProvider.future);

  return ZohoContactsService(api: api, routes: routes);
});

class ZohoContactsService {
  ZohoContactsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  Future<List<ZohoContact>> list({
    String? search,
    int limit = 50,
    int page = 1,
  }) async {
    final uri = routes.zohoListContacts(
      search: search,
      limit: limit,
      page: page,
    );

    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final contactsRaw = data['contacts'];

    if (contactsRaw is List) {
      return contactsRaw
          .whereType<Map>()
          .map((m) => ZohoContact.fromJson(m.cast<String, dynamic>()))
          .toList();
    }

    return <ZohoContact>[];
  }

  Future<ZohoContact> create(ZohoContact input) async {
    final uri = routes.zohoCreateContact();
    final res = await api.postUri(uri, data: input.toCreateJson());

    final data = _asJsonMap(res.data);
    final raw = data['contact'];
    if (raw is Map) {
      return ZohoContact.fromJson(raw.cast<String, dynamic>());
    }
    throw StateError('Unexpected response shape: missing "contact"');
  }

  Future<ZohoContact> update(String contactId, ZohoContact input) async {
    final uri = routes.zohoUpdateContact(contactId);
    final res = await api.putUri(uri, data: input.toUpdateJson());

    final data = _asJsonMap(res.data);
    final raw = data['contact'];
    if (raw is Map) {
      return ZohoContact.fromJson(raw.cast<String, dynamic>());
    }
    throw StateError('Unexpected response shape: missing "contact"');
  }

  Future<void> delete(String contactId) async {
    final uri = routes.zohoDeleteContact(contactId);
    await api.deleteUri(uri);
  }

  JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
