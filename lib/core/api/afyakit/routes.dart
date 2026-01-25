// lib/core/api/afyakit/routes.dart

import 'package:afyakit/core/api/afyakit/config.dart';
import 'package:afyakit/core/api/shared/uri.dart';
import 'package:afyakit/features/inventory/locations/inventory_location_type_enum.dart';

class AfyaKitRoutes {
  AfyaKitRoutes(String tenantId) : tenantId = tenantId.trim().toLowerCase();

  /// Tenant slug/id used in API base: .../api/:tenantId
  final String tenantId;

  // ─────────────────────────────────────────────
  // Bases
  // ─────────────────────────────────────────────

  /// Tenant base: https://host/api/:tenantId
  String get _tenantBase => apiBaseUrl(tenantId);

  /// Core base: https://host/api
  ///
  /// We derive it by removing the final path segment if it equals [tenantId].
  String get _coreBase {
    final u = Uri.parse(_tenantBase);

    // Normalize path segments (avoid surprises from trailing slashes).
    final segs = u.pathSegments.where((s) => s.trim().isNotEmpty).toList();

    if (segs.isNotEmpty && segs.last.toLowerCase() == tenantId) {
      final coreSegs = segs.take(segs.length - 1).toList();
      return u.replace(pathSegments: coreSegs).toString();
    }

    // Fallback: if config already points to core, keep it.
    return u.toString();
  }

  Uri _uri(String path, {Map<String, String>? query}) {
    final p = _cleanPath(path);
    final uri = Uri.parse(joinBaseAndPath(_tenantBase, p));
    debugUri('URI tenant', uri);
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  Uri _uriCore(String path, {Map<String, String>? query}) {
    final p = _cleanPath(path);
    final uri = Uri.parse(joinBaseAndPath(_coreBase, p));
    debugUri('URI core', uri);
    return query != null ? uri.replace(queryParameters: query) : uri;
  }

  static String _cleanPath(String path) {
    final p = path.trim();
    if (p.isEmpty) return '';
    return p.startsWith('/') ? p.substring(1) : p;
  }

  String _seg(String s) => Uri.encodeComponent(s.trim());

  // ─────────────────────────────────────────────
  // 🔐 Public auth (tenant-scoped; no auth header)
  // ─────────────────────────────────────────────

  Uri checkUserStatus() => _uri('auth_login/check-user-status');
  Uri waStart() => _uri('auth_login/wa/start');
  Uri smsStart() => _uri('auth_login/sms/start');
  Uri emailStart() => _uri('auth_login/email/start');
  Uri otpVerify() => _uri('auth_login/otp/verify');

  // ─────────────────────────────────────────────
  // 👤 Auth Session (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getCurrentUser() => _uri('auth/session/me');
  Uri syncClaims() => _uri('auth/session/sync-claims');

  // ─────────────────────────────────────────────
  // 👥 Auth Users (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getAllUsers() => _uri('auth_users');
  Uri getUserById(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri updateUser(String uid) => _uri('auth_users/${_seg(uid)}');
  Uri deleteUser(String uid) => _uri('auth_users/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // 🧑‍💼 HQ / Global (core; superadmin-gated on server)
  // ─────────────────────────────────────────────

  Uri listGlobalUsers({
    String? tenant,
    String? search,
    int limit = 50,
  }) => _uriCore(
    'users',
    query: {
      if (tenant != null && tenant.trim().isNotEmpty) 'tenantId': tenant.trim(),
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
    },
  );

  Uri createGlobalUser() => _uriCore('users');
  Uri updateGlobalUser(String uid) => _uriCore('users/${_seg(uid)}');
  Uri deleteGlobalUser(String uid) => _uriCore('users/${_seg(uid)}');

  Uri fetchUserMemberships(String uid) =>
      _uriCore('users/${_seg(uid)}/memberships');

  Uri listSuperAdmins() => _uriCore('superadmins');
  Uri setSuperAdmin(String uid) => _uriCore('superadmins/${_seg(uid)}');

  Uri hqListTenantUsers(
    String targetTenantId, {
    String? search,
    int limit = 50,
  }) => _uriCore(
    'tenants/${_seg(targetTenantId)}/auth_users',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
    },
  );

  Uri hqUpsertUserMembership(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  Uri hqDeleteUser(String targetTenantId, String uid) =>
      _uriCore('tenants/${_seg(targetTenantId)}/auth_users/${_seg(uid)}');

  // ─────────────────────────────────────────────
  // 🏢 Tenants (HQ/global; core)
  // ─────────────────────────────────────────────

  Uri listTenants() => _uriCore('tenants');
  Uri createTenant() => _uriCore('tenants');
  Uri getTenant(String slug) => _uriCore('tenants/${_seg(slug)}');
  Uri updateTenant(String slug) => _uriCore('tenants/${_seg(slug)}');
  Uri deleteTenant(String slug) => _uriCore('tenants/${_seg(slug)}');

  Uri setTenantStatus(String slug) => _uriCore('tenants/${_seg(slug)}/status');
  Uri setTenantFlag(String slug, String key) =>
      _uriCore('tenants/${_seg(slug)}/flags/${_seg(key)}');

  Uri setTenantOwner(String slug) => _uriCore('tenants/${_seg(slug)}/owner');
  Uri removeTenantOwner(String slug) => _uriCore('tenants/${_seg(slug)}/owner');

  Uri listDomains(String slug) => _uriCore('tenants/${_seg(slug)}/domains');
  Uri addDomain(String slug) => _uriCore('tenants/${_seg(slug)}/domains');

  Uri verifyDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/verify');

  Uri makePrimaryDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}/primary');

  Uri removeDomain(String slug, String domain) =>
      _uriCore('tenants/${_seg(slug)}/domains/${_seg(domain)}');

  // ─────────────────────────────────────────────
  // 📦 Inventory (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri inventory(String itemType) =>
      _uri('inventory', query: {'type': itemType});
  Uri createItem() => _uri('inventory');

  Uri itemById(String id, {String? type}) => _uri(
    'inventory/${_seg(id)}',
    query: (type != null && type.trim().isNotEmpty)
        ? {'type': type.trim()}
        : null,
  );

  // ─────────────────────────────────────────────
  // ⚙️ Preferences (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri preferenceField(String itemType, String field) =>
      _uri('preferences/${_seg(itemType)}/${_seg(field)}');

  // ─────────────────────────────────────────────
  // 📍 Inventory Locations (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri getTypedLocations(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');

  Uri addTypedLocation(InventoryLocationType type) =>
      _uri('inventory-locations/${type.asString}');

  Uri deleteTypedLocation(InventoryLocationType type, String id) =>
      _uri('inventory-locations/${type.asString}/${_seg(id)}');

  // ─────────────────────────────────────────────
  // 🧪 Batches (tenant-scoped; authenticated, per store)
  // ─────────────────────────────────────────────

  Uri listBatches(String storeId) => _uri('stores/${_seg(storeId)}/batches');
  Uri createBatch(String storeId) => _uri('stores/${_seg(storeId)}/batches');
  Uri updateBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');
  Uri deleteBatch(String storeId, String batchId) =>
      _uri('stores/${_seg(storeId)}/batches/${_seg(batchId)}');

  // ─────────────────────────────────────────────
  // 📥 Imports (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri importInventory({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'imports/inventory',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importInventoryRaw({
    required String type,
    bool dryRun = true,
    bool persist = false,
  }) => _uri(
    'imports/inventory-raw',
    query: {'type': type, 'dryRun': '$dryRun', 'persist': '$persist'},
  );

  Uri importTemplate(String type) => _uri('imports/templates/$type');

  // ─────────────────────────────────────────────
  // 🏓 Ping
  // ─────────────────────────────────────────────

  Uri ping() => _uri('ping');

  // ─────────────────────────────────────────────
  // 💊 DawaIndex Proxy (tenant-scoped; authenticated or public depending on BE)
  // ─────────────────────────────────────────────

  Uri diSalesTiles({String? q, String? form, int limit = 50, int offset = 0}) =>
      _uri(
        'dawaindex/v1/sales/tiles',
        query: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
          if (form != null && form.trim().isNotEmpty) 'form': form.trim(),
          'limit': '$limit',
          'offset': '$offset',
        },
      );

  // ─────────────────────────────────────────────
  // 💼 Zoho OAuth callback (core; not tenant-scoped)
  // ─────────────────────────────────────────────

  Uri zohoOAuthCallback() => _uriCore('zoho/oauth/callback');

  // ─────────────────────────────────────────────
  // 💼 Zoho Books (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  Uri zohoListContacts({
    String? search,
    String? type,
    int limit = 50,
    int page = 1,
  }) => _uri(
    'zoho/v1/contacts',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      'limit': '$limit',
      'page': '$page',
    },
  );

  Uri zohoListCustomers({String? search, int limit = 50, int page = 1}) => _uri(
    'zoho/v1/contacts/customers',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      'limit': '$limit',
      'page': '$page',
    },
  );

  Uri zohoGetContact(String contactId) =>
      _uri('zoho/v1/contacts/${_seg(contactId)}');
  Uri zohoCreateContact() => _uri('zoho/v1/contacts');
  Uri zohoUpdateContact(String contactId) =>
      _uri('zoho/v1/contacts/${_seg(contactId)}');
  Uri zohoDeleteContact(String contactId) =>
      _uri('zoho/v1/contacts/${_seg(contactId)}');

  // ─────────────────────────────────────────────
  // 💼 Zoho Quotes
  // ─────────────────────────────────────────────

  Uri zohoListQuotes({int limit = 50, int page = 1}) =>
      _uri('zoho/v1/quotes', query: {'limit': '$limit', 'page': '$page'});

  Uri zohoGetQuote(String quoteId) => _uri('zoho/v1/quotes/${_seg(quoteId)}');
  Uri zohoCreateQuote() => _uri('zoho/v1/quotes');
  Uri zohoUpdateQuote(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}');
  Uri zohoDeleteQuote(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}');

  Uri zohoQuotePdf(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/pdf');
  Uri zohoSendQuote(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/email');
  Uri zohoMarkQuoteSent(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/status/sent');
  Uri zohoConvertQuoteToInvoice(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/convert-to-invoice');

  // ─────────────────────────────────────────────
  // 💼 Zoho Invoices
  // ─────────────────────────────────────────────

  Uri zohoListInvoices({int limit = 50, int page = 1}) =>
      _uri('zoho/v1/invoices', query: {'limit': '$limit', 'page': '$page'});

  Uri zohoGetInvoice(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}');

  Uri zohoUpdateInvoice(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}');

  Uri zohoInvoicePdf(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}/pdf');

  Uri zohoSendInvoice(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}/email');

  Uri zohoMarkInvoiceSent(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}/status/sent');

  // ─────────────────────────────────────────────
  // 💳 Zoho Payments
  // ─────────────────────────────────────────────

  /// GET /zoho/v1/payments?invoice_id=...&per_page=...&page=...
  Uri zohoInvoicePayments(
    String invoiceId, {
    int perPage = 200,
    int page = 1,
  }) => _uri(
    'zoho/v1/payments',
    query: {
      'invoice_id': invoiceId.trim(),
      'per_page': '$perPage',
      'page': '$page',
    },
  );

  Uri zohoPaymentsList({int perPage = 200, int page = 1, String? invoiceId}) =>
      _uri(
        'zoho/v1/payments',
        query: {
          if (invoiceId != null && invoiceId.trim().isNotEmpty)
            'invoice_id': invoiceId.trim(),
          'per_page': '$perPage',
          'page': '$page',
        },
      );

  Uri zohoPaymentsCreate() => _uri('zoho/v1/payments');

  Uri zohoPaymentsGet(String paymentId) =>
      _uri('zoho/v1/payments/${_seg(paymentId)}');

  Uri zohoPaymentsUpdate(String paymentId) =>
      _uri('zoho/v1/payments/${_seg(paymentId)}');

  Uri zohoPaymentsDelete(String paymentId) =>
      _uri('zoho/v1/payments/${_seg(paymentId)}');

  // ─────────────────────────────────────────────
  // 🧾 Zoho Meta (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// Chart of Accounts
  /// GET /zoho/v1/meta/accounts?search=&type=&active=
  Uri zohoMetaAccounts({String? search, String? type, bool? active}) => _uri(
    'zoho/v1/meta/accounts',
    query: {
      if (search != null && search.trim().isNotEmpty) 'search': search.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (active != null) 'active': active ? 'true' : 'false',
    },
  );

  /// Optional: single account
  /// GET /zoho/v1/meta/accounts/:accountId
  Uri zohoMetaAccountById(String accountId) =>
      _uri('zoho/v1/meta/accounts/${_seg(accountId)}');

  // ─────────────────────────────────────────────
  // 📲 M-Pesa (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// POST /api/:tenantId/mpesa/stk/initiate
  Uri mpesaStkInitiate() => _uri('mpesa/stk/initiate');

  /// GET /api/:tenantId/mpesa/payments/:paymentId
  Uri mpesaPaymentStatus(String paymentId) =>
      _uri('mpesa/payments/${_seg(paymentId)}');
}
