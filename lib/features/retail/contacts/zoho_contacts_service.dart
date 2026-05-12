// lib/features/retail/contacts/zoho_contacts_service.dart

import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/contacts/zoho_contact.dart';

import 'package:afyakit/core/api/afyakit/client.dart';
import 'package:afyakit/core/api/afyakit/routes/routes.dart';
import 'package:afyakit/core/api/afyakit/providers.dart';
import 'package:afyakit/core/hq/tenants/providers/tenant_providers.dart';

final zohoContactsServiceProvider = FutureProvider<ZohoContactsService>((
  ref,
) async {
  final tenantId = ref.watch(tenantIdProvider);
  final routes = AfyaKitRoutes(tenantId);
  final api = await ref.watch(afyakitClientFutureProvider.future);

  return ZohoContactsService(api: api, routes: routes);
});

/// One-liner provider for UI: "give me contact by id"
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

  /// Account-number keyed cache for member-scoped customer resolution.
  final Map<String, ZohoContact> _accountCache = <String, ZohoContact>{};

  static const bool _debug = false;

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

    // If backend didn't include contact_type, do not over-filter client-side.
    // Server-side filtering is the real guard.
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

  /// Ensures we use Zoho/BE expected search parameter: `search_text`.
  Uri _withSearchText(Uri uri, String? search) {
    final q = (search ?? '').trim();
    if (q.isEmpty) return uri;

    final qp = Map<String, String>.from(uri.queryParameters);
    qp.remove('search');
    qp['search_text'] = q;

    return uri.replace(queryParameters: qp);
  }

  Uri _withInsurancePayerFilter(Uri uri, bool? isInsurancePayer) {
    if (isInsurancePayer == null) return uri;

    final qp = Map<String, String>.from(uri.queryParameters);
    qp['is_insurance_payer'] = isInsurancePayer ? 'true' : 'false';

    return uri.replace(queryParameters: qp);
  }

  String _acctKey(String? accountNumber) => (accountNumber ?? '').trim();

  void _cacheByAccount(ZohoContact contact) {
    final acct = _acctKey(contact.accountNumber);
    if (acct.isEmpty) return;

    _accountCache[acct] = contact;
  }

  void _evictAccount(String? accountNumber) {
    final acct = _acctKey(accountNumber);
    if (acct.isEmpty) return;

    _accountCache.remove(acct);
  }

  ZohoContact _pickBestAccountMatch(
    List<ZohoContact> items, {
    required String accountNumber,
  }) {
    final acct = _acctKey(accountNumber);

    if (acct.isEmpty) {
      throw StateError('accountNumber is empty');
    }

    if (items.isEmpty) {
      throw StateError('No contacts found for account number');
    }

    final exact = items
        .where((c) => _acctKey(c.accountNumber) == acct)
        .toList(growable: false);

    return exact.isNotEmpty ? exact.first : items.first;
  }

  Future<List<ZohoContact>> list({
    String? search,
    int perPage = 50,
    int page = 1,
    ZohoContactTypeFilter type = ZohoContactTypeFilter.customerOnly,
    String? accountNumber,
    bool? isInsurancePayer,
  }) async {
    final cleanSearch = (search ?? '').trim();
    final cleanAcct = _acctKey(accountNumber);

    final uri0 = routes.retailListContacts(
      search: cleanSearch.isEmpty ? null : cleanSearch,
      perPage: perPage,
      page: page,
      type: _toZohoType(type),
      accountNumber: cleanAcct.isEmpty ? null : cleanAcct,
    );

    final uri = _withInsurancePayerFilter(
      _withSearchText(uri0, cleanSearch),
      isInsurancePayer,
    );

    if (_debug) {
      debugPrint(
        '[ZohoContactsService.list] q="$cleanSearch" '
        'account="$cleanAcct" insurancePayer="$isInsurancePayer" uri=$uri',
      );
    }

    final res = await api.getUri<Object?>(uri);
    final data = _asJsonMap(res.data);

    final raw = data['contacts'];
    if (raw is! List) return const <ZohoContact>[];

    final items = raw
        .whereType<Map>()
        .map((m) => ZohoContact.fromJson(m.cast<String, Object?>()))
        .toList(growable: false);

    final filteredByType = type == ZohoContactTypeFilter.any
        ? items
        : items.where((c) => _matchesFilter(c, type)).toList(growable: false);

    final filtered = isInsurancePayer == null
        ? filteredByType
        : filteredByType
              .where((c) => c.isInsurancePayer == isInsurancePayer)
              .toList(growable: false);

    for (final contact in filtered) {
      _cacheByAccount(contact);
    }

    if (cleanAcct.isNotEmpty && filtered.isNotEmpty) {
      final best = _pickBestAccountMatch(filtered, accountNumber: cleanAcct);
      _cacheByAccount(best);
    }

    return filtered;
  }

  Future<List<ZohoContact>> listInsurancePayers({
    String? search,
    int perPage = 100,
    int page = 1,
  }) {
    return list(
      search: search,
      perPage: perPage,
      page: page,
      type: ZohoContactTypeFilter.customerOnly,
      isInsurancePayer: true,
    );
  }

  Future<ZohoContact?> getByAccountNumber(
    String accountNumber, {
    ZohoContactTypeFilter type = ZohoContactTypeFilter.customerOnly,
    bool forceRefresh = false,
  }) async {
    final acct = _acctKey(accountNumber);
    if (acct.isEmpty) return null;

    if (!forceRefresh) {
      final cached = _accountCache[acct];
      if (cached != null) return cached;
    }

    final items = await list(
      accountNumber: acct,
      type: type,
      perPage: 50,
      page: 1,
    );

    if (items.isEmpty) return null;

    final best = _pickBestAccountMatch(items, accountNumber: acct);
    _cacheByAccount(best);

    return best;
  }

  Future<ZohoContact> get(String contactId) async {
    final id = contactId.trim();

    if (id.isEmpty) {
      throw StateError('contactId is empty');
    }

    final uri = routes.retailGetContact(id);
    final res = await api.getUri<Object?>(uri);

    final data = _asJsonMap(res.data);
    final raw = data['contact'];

    if (raw is Map) {
      final contact = ZohoContact.fromJson(raw.cast<String, Object?>());
      _cacheByAccount(contact);
      return contact;
    }

    throw StateError('Unexpected response shape: missing "contact"');
  }

  /// Lightweight contact fetch.
  ///
  /// This calls:
  ///   GET /zoho/v1/contacts/:contactId?light=true
  ///
  /// Use this for fast member quote binding where we only need identity/scope
  /// fields and do not need linked patients or contact-person enrichment.
  Future<ZohoContact> getLight(String contactId) async {
    final id = contactId.trim();

    if (id.isEmpty) {
      throw StateError('contactId is empty');
    }

    final base = routes.retailGetContact(id);
    final uri = base.replace(
      queryParameters: <String, String>{
        ...base.queryParameters,
        'light': 'true',
      },
    );

    if (_debug) {
      debugPrint('[ZohoContactsService.getLight] uri=$uri');
    }

    final res = await api.getUri<Object?>(uri);

    final data = _asJsonMap(res.data);
    final raw = data['contact'];

    if (raw is Map) {
      final contact = ZohoContact.fromJson(raw.cast<String, Object?>());
      _cacheByAccount(contact);
      return contact;
    }

    throw StateError('Unexpected response shape: missing "contact"');
  }

  Future<ZohoContact?> getOrNull(String contactId) async {
    final id = contactId.trim();
    if (id.isEmpty) return null;

    try {
      return await get(id);
    } catch (_) {
      return null;
    }
  }

  Future<ZohoContact?> getLightOrNull(String contactId) async {
    final id = contactId.trim();
    if (id.isEmpty) return null;

    try {
      return await getLight(id);
    } catch (_) {
      return null;
    }
  }

  Future<ZohoContact> create(ZohoContact input) async {
    final uri = routes.retailCreateContact();
    final res = await api.postUri<Object?>(uri, data: input.toCreateJson());

    final data = _asJsonMap(res.data);
    final raw = data['contact'];

    if (raw is Map) {
      final contact = ZohoContact.fromJson(raw.cast<String, Object?>());
      _cacheByAccount(contact);
      return contact;
    }

    throw StateError('Unexpected response shape: missing "contact"');
  }

  Future<ZohoContact> updatePatch(
    String contactId,
    ContactUpdatePatch patch,
  ) async {
    final id = contactId.trim();

    if (id.isEmpty) {
      throw StateError('contactId is empty');
    }

    final uri = routes.retailUpdateContact(id);
    final body = patch.toJson();

    if (patch.personContact?.delete == true) {
      body['person_contact'] = null;
    }

    final res = await api.putUri<Object?>(uri, data: body);

    final data = _asJsonMap(res.data);
    final raw = data['contact'];

    if (raw is Map) {
      final contact = ZohoContact.fromJson(raw.cast<String, Object?>());
      _cacheByAccount(contact);
      return contact;
    }

    throw StateError('Unexpected response shape: missing "contact"');
  }

  Future<ZohoContact> updateFromModel(
    String contactId,
    ZohoContact input,
  ) async {
    final oldAcct = _acctKey(input.accountNumber);

    final patch = ContactUpdatePatch(
      displayName: input.displayName,
      companyName: input.companyName,
      accountNumber: input.accountNumber,
      isInsurancePayer: input.isInsurancePayer,
      personContact: input.personContact == null
          ? const PersonContactPatch(delete: true)
          : PersonContactPatch(
              personName: input.personContact!.personName,
              email: input.personContact!.email,
              phone: input.personContact!.phone,
              mobile: input.personContact!.mobile,
            ),
    );

    final updated = await updatePatch(contactId, patch);

    final newAcct = _acctKey(updated.accountNumber);
    if (oldAcct.isNotEmpty && oldAcct != newAcct) {
      _evictAccount(oldAcct);
    }

    _cacheByAccount(updated);

    return updated;
  }

  Future<void> delete(String contactId) async {
    final id = contactId.trim();

    if (id.isEmpty) {
      throw StateError('contactId is empty');
    }

    final existing = await getOrNull(id);
    final existingAcct = _acctKey(existing?.accountNumber);

    final uri = routes.retailDeleteContact(id);
    await api.deleteUri<Object?>(uri);

    if (existingAcct.isNotEmpty) {
      _evictAccount(existingAcct);
    }
  }

  JsonMap _asJsonMap(Object? v) {
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();

    throw StateError('Expected JSON object but got ${v.runtimeType}');
  }
}
