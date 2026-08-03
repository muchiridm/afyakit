// lib/features/retail/contacts/services/zoho_contacts_service.dart

import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/contacts/models/zoho_contact.dart';

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
    int perPage = 100,
    int page = 1,
    ZohoContactTypeFilter type = ZohoContactTypeFilter.customerOnly,
    String? accountNumber,
    bool? isInsurancePayer,
  }) async {
    final cleanSearch = (search ?? '').trim();
    final cleanAcct = _acctKey(accountNumber);

    final startPage = page < 1 ? 1 : page;
    final safePerPage = perPage.clamp(1, 100);

    // For normal list/search, fetch several pages because Zoho may not return
    // company/business contacts on the first page.
    final maxPages = cleanSearch.isNotEmpty ? 5 : 5;

    final byId = <String, ZohoContact>{};

    for (int offset = 0; offset < maxPages; offset += 1) {
      final currentPage = startPage + offset;

      final uri0 = routes.retailListContacts(
        search: cleanSearch.isEmpty ? null : cleanSearch,
        perPage: safePerPage,
        page: currentPage,
        // Important: do not force type=customer from FE.
        // Some Zoho company/business contacts may not behave as expected with
        // contact_type filtering. Let backend/Zoho return them, then filter safely.
        type: _toZohoType(type),
        accountNumber: cleanAcct.isEmpty ? null : cleanAcct,
      );

      final uri = _withInsurancePayerFilter(
        _withSearchText(uri0, cleanSearch),
        isInsurancePayer,
      );

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[FE][ZohoContactsService.list] GET page=$currentPage');
      debugPrint('[FE][ZohoContactsService.list] uri=$uri');
      debugPrint('[FE][ZohoContactsService.list] search="$cleanSearch"');
      debugPrint('[FE][ZohoContactsService.list] type=$type');
      debugPrint('[FE][ZohoContactsService.list] account="$cleanAcct"');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final res = await api.getUri<Object?>(uri);
      final data = _asJsonMap(res.data);

      final raw = data['contacts'];
      if (raw is! List) {
        debugPrint('[FE][ZohoContactsService.list] contacts missing/not list');
        break;
      }

      final pageItems = raw
          .whereType<Map>()
          .map((m) => ZohoContact.fromJson(m.cast<String, Object?>()))
          .toList(growable: false);

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint(
        '[FE][ZohoContactsService.list] page=$currentPage count=${pageItems.length}',
      );
      debugPrint(
        '[FE][ZohoContactsService.list] page items=${pageItems.map((c) => {'id': c.contactId, 'title': c.title, 'display': c.displayName, 'company': c.companyName, 'person': c.personContact?.personName, 'type': c.contactType, 'isCompanyOnly': c.isCompanyOnly}).take(30).toList()}',
      );
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      for (final contact in pageItems) {
        final id = contact.contactId.trim();
        if (id.isEmpty) continue;
        byId[id] = contact;
      }

      if (pageItems.length < safePerPage) break;
    }

    var items = byId.values.toList(growable: false);

    // Safe client-side type filter.
    // If type is any, keep all contacts.
    // If backend/Zoho omitted contact_type, keep the contact rather than hiding it.
    final filteredByType = type == ZohoContactTypeFilter.any
        ? items
        : items.where((c) => _matchesFilter(c, type)).toList(growable: false);

    final filteredByInsurance = isInsurancePayer == null
        ? filteredByType
        : filteredByType
              .where((c) => c.isInsurancePayer == isInsurancePayer)
              .toList(growable: false);

    final q = cleanSearch.toLowerCase();

    final filteredBySearch = q.isEmpty
        ? filteredByInsurance
        : filteredByInsurance
              .where((c) {
                final fields = <String>[
                  c.title,
                  c.displayName,
                  c.companyName ?? '',
                  c.personContact?.personName ?? '',
                  c.bestPhone,
                  c.bestEmail,
                  c.accountNumber ?? '',
                  c.contactId,
                  c.contactType ?? '',
                ];

                return fields.any((v) => v.trim().toLowerCase().contains(q));
              })
              .toList(growable: false);

    for (final contact in filteredBySearch) {
      _cacheByAccount(contact);
    }

    if (cleanAcct.isNotEmpty && filteredBySearch.isNotEmpty) {
      final best = _pickBestAccountMatch(
        filteredBySearch,
        accountNumber: cleanAcct,
      );
      _cacheByAccount(best);
    }

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint(
      '[FE][ZohoContactsService.list] FINAL count=${filteredBySearch.length}',
    );
    debugPrint(
      '[FE][ZohoContactsService.list] FINAL=${filteredBySearch.map((c) => {'id': c.contactId, 'title': c.title, 'company': c.companyName, 'person': c.personContact?.personName, 'type': c.contactType, 'isCompanyOnly': c.isCompanyOnly}).take(50).toList()}',
    );
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    return filteredBySearch;
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
    final body = input.toCreateJson();

    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('[FE][ZohoContactsService.create] START');
    debugPrint('[FE][ZohoContactsService.create] uri=$uri');
    debugPrint('[FE][ZohoContactsService.create] body=$body');
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

    try {
      final res = await api.postUri<Object?>(uri, data: body);

      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[FE][ZohoContactsService.create] RESPONSE');
      debugPrint('[FE][ZohoContactsService.create] status=${res.statusCode}');
      debugPrint('[FE][ZohoContactsService.create] data=${res.data}');
      debugPrint('[FE][ZohoContactsService.create] headers=${res.headers}');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');

      final data = _asJsonMap(res.data);
      final raw = data['contact'];

      if (raw is Map) {
        final contact = ZohoContact.fromJson(raw.cast<String, Object?>());

        debugPrint('[FE][ZohoContactsService.create] parsed contact:');
        debugPrint('  contactId=${contact.contactId}');
        debugPrint('  displayName=${contact.displayName}');
        debugPrint('  accountNumber=${contact.accountNumber}');
        debugPrint('  contactType=${contact.contactType}');
        debugPrint('  status=${contact.status}');

        _cacheByAccount(contact);
        return contact;
      }

      debugPrint(
        '[FE][ZohoContactsService.create] ERROR missing contact in response',
      );

      throw StateError('Unexpected response shape: missing "contact"');
    } catch (e, st) {
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      debugPrint('[FE][ZohoContactsService.create] FAILED');
      debugPrint('[FE][ZohoContactsService.create] error=$e');
      debugPrint('[FE][ZohoContactsService.create] stack=$st');
      debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
      rethrow;
    }
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
