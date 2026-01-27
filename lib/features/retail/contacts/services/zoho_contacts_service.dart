// lib/features/retail/contacts/services/zoho_contacts_service.dart

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/tenancy/providers/tenant_providers.dart';

typedef JsonMap = Map<String, dynamic>;

final zohoContactsServiceProvider = FutureProvider<ZohoContactsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantSlugProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientProvider.future);
  return ZohoContactsService(api: api, routes: routes);
});

/// ✅ One-liner provider for UI: "give me contact by id"
final zohoContactByIdProvider = FutureProvider.family
    .autoDispose<ZohoContact, String>((ref, contactId) {
      final id = contactId.trim();
      if (id.isEmpty) {
        throw StateError('contactId is empty');
      }
      return ref
          .read(zohoContactsServiceProvider.future)
          .then((svc) => svc.get(id));
    });

enum ZohoContactTypeFilter { any, customerOnly, vendorOnly }

class ZohoContactsService {
  ZohoContactsService({required this.api, required this.routes});

  final AfyaKitClient api;
  final AfyaKitRoutes routes;

  static String? _toZohoType(ZohoContactTypeFilter f) {
    switch (f) {
      case ZohoContactTypeFilter.any:
        return null;
      case ZohoContactTypeFilter.customerOnly:
        return 'customer';
      case ZohoContactTypeFilter.vendorOnly:
        return 'vendor';
    }
  }

  static bool _matchesFilter(ZohoContact c, ZohoContactTypeFilter f) {
    if (f == ZohoContactTypeFilter.any) return true;

    final t = (c.contactType ?? '').trim().toLowerCase();

    // If backend didn't include contact_type, we cannot trust client-side filtering.
    // In that case, just allow it through (server-side filter is the real guard).
    if (t.isEmpty) return true;

    switch (f) {
      case ZohoContactTypeFilter.customerOnly:
        return t == 'customer' || t == 'customer_vendor';
      case ZohoContactTypeFilter.vendorOnly:
        return t == 'vendor' || t == 'customer_vendor';
      case ZohoContactTypeFilter.any:
        return true;
    }
  }

  Future<List<ZohoContact>> list({
    String? search,
    int limit = 50,
    int page = 1,
    ZohoContactTypeFilter type = ZohoContactTypeFilter.customerOnly,
  }) async {
    final uri = routes.zohoListContacts(
      search: search,
      limit: limit,
      page: page,
      type: _toZohoType(type),
    );

    final res = await api.getUri(uri);
    final data = _asJsonMap(res.data);

    final raw = data['contacts'];
    if (raw is! List) return const <ZohoContact>[];

    final items = raw
        .whereType<Map>()
        .map((m) => ZohoContact.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);

    if (type == ZohoContactTypeFilter.any) return items;
    return items.where((c) => _matchesFilter(c, type)).toList(growable: false);
  }

  Future<ZohoContact> get(String contactId) async {
    final uri = routes.zohoGetContact(contactId);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['contact'];
    if (raw is Map) {
      return ZohoContact.fromJson(raw.cast<String, dynamic>());
    }
    throw StateError('Unexpected response shape: missing "contact"');
  }

  /// ✅ UI-friendly helper: best-effort fetch.
  Future<ZohoContact?> getOrNull(String contactId) async {
    final id = contactId.trim();
    if (id.isEmpty) return null;
    try {
      return await get(id);
    } catch (_) {
      return null;
    }
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

  Future<ZohoContact> updatePatch(
    String contactId,
    ContactUpdatePatch patch,
  ) async {
    final uri = routes.zohoUpdateContact(contactId);

    final body = patch.toJson();

    if (patch.personContact?.delete == true) {
      body['person_contact'] = null;
    }

    final res = await api.putUri(uri, data: body);

    final data = _asJsonMap(res.data);
    final raw = data['contact'];
    if (raw is Map) {
      return ZohoContact.fromJson(raw.cast<String, dynamic>());
    }
    throw StateError('Unexpected response shape: missing "contact"');
  }

  Future<ZohoContact> updateFromModel(
    String contactId,
    ZohoContact input,
  ) async {
    final patch = ContactUpdatePatch(
      displayName: input.displayName,
      companyName: input.companyName,

      // ✅ NEW: allow updating/repairing reference_number
      referenceNumber: input.referenceNumber,

      personContact: input.personContact == null
          ? const PersonContactPatch(delete: true)
          : PersonContactPatch(
              personName: input.personContact!.personName,
              email: input.personContact!.email,
              phone: input.personContact!.phone,
              mobile: input.personContact!.mobile,
            ),
    );

    return updatePatch(contactId, patch);
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
