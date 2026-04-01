// lib/features/retail/contacts/services/zoho_contacts_service.dart

import 'package:afyakit/shared/utils/utils.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:afyakit/features/retail/shared/models/zoho_contact.dart';

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

  /// Account-number keyed cache for member-scoped customer resolution.
  final Map<String, ZohoContact> _accountCache = <String, ZohoContact>{};

  /// Flip this to true temporarily when debugging.
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

  /// Ensures we use Zoho's expected search parameter: `search_text`
  Uri _withSearchText(Uri uri, String? search) {
    final q = (search ?? '').trim();
    if (q.isEmpty) return uri;

    final qp = Map<String, String>.from(uri.queryParameters);

    if (qp.containsKey('search')) {
      qp.remove('search');
    }

    qp['search_text'] = q;

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

    final pool = exact.isNotEmpty ? exact : items;
    return pool.first;
  }

  Future<List<ZohoContact>> list({
    String? search,
    int perPage = 50,
    int page = 1,
    ZohoContactTypeFilter type = ZohoContactTypeFilter.customerOnly,

    /// ✅ If present, backend will return ONLY matching contact(s)
    /// (member hard-scope)
    String? accountNumber,
  }) async {
    final cleanSearch = (search ?? '').trim();
    final cleanAcct = _acctKey(accountNumber);

    final uri0 = routes.zohoListContacts(
      search: cleanSearch.isEmpty ? null : cleanSearch,
      perPage: perPage,
      page: page,
      type: _toZohoType(type),
      accountNumber: cleanAcct.isEmpty ? null : cleanAcct,
    );

    final uri = _withSearchText(uri0, cleanSearch);

    if (_debug) {
      debugPrint(
        '[ZohoContactsService.list] q="$cleanSearch" account="$cleanAcct" uri=$uri',
      );
    }

    final res = await api.getUri(uri);
    final data = _asJsonMap(res.data);

    final raw = data['contacts'];
    if (raw is! List) return const <ZohoContact>[];

    final items = raw
        .whereType<Map>()
        .map((m) => ZohoContact.fromJson(m.cast<String, dynamic>()))
        .toList(growable: false);

    final filtered = type == ZohoContactTypeFilter.any
        ? items
        : items.where((c) => _matchesFilter(c, type)).toList(growable: false);

    // Warm the account cache whenever we are doing an account-scoped fetch.
    if (cleanAcct.isNotEmpty && filtered.isNotEmpty) {
      final best = _pickBestAccountMatch(filtered, accountNumber: cleanAcct);
      _cacheByAccount(best);
    }

    return filtered;
  }

  /// Fast path for member-scoped lookup.
  /// Returns cached value when available, otherwise fetches once and caches it.
  Future<ZohoContact?> getByAccountNumber(
    String accountNumber, {
    ZohoContactTypeFilter type = ZohoContactTypeFilter.customerOnly,
    bool forceRefresh = false,
  }) async {
    final acct = _acctKey(accountNumber);
    if (acct.isEmpty) return null;

    if (!forceRefresh) {
      final cached = _accountCache[acct];
      if (cached != null) {
        return cached;
      }
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
    final uri = routes.zohoGetContact(contactId);
    final res = await api.getUri(uri);

    final data = _asJsonMap(res.data);
    final raw = data['contact'];
    if (raw is Map) {
      final contact = ZohoContact.fromJson(raw.cast<String, dynamic>());
      _cacheByAccount(contact);
      return contact;
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
      final contact = ZohoContact.fromJson(raw.cast<String, dynamic>());
      _cacheByAccount(contact);
      return contact;
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
      final contact = ZohoContact.fromJson(raw.cast<String, dynamic>());
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

    // If account number changed, evict stale old mapping and cache the new one.
    final newAcct = _acctKey(updated.accountNumber);
    if (oldAcct.isNotEmpty && oldAcct != newAcct) {
      _evictAccount(oldAcct);
    }
    _cacheByAccount(updated);

    return updated;
  }

  Future<void> delete(String contactId) async {
    // Best effort: fetch before delete so we can evict any cached account mapping.
    final existing = await getOrNull(contactId);
    final existingAcct = _acctKey(existing?.accountNumber);

    final uri = routes.zohoDeleteContact(contactId);
    await api.deleteUri(uri);

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
