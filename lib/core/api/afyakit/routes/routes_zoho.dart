// lib/core/api/afyakit/routes/routes_zoho.dart

part of 'routes.dart';

extension AfyaKitZohoRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 💼 Zoho Books (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// NOTE: Zoho Books uses `search_text` (not `search`) for list filters.
  /// BE also supports member scoping via `account_number`.
  Uri zohoListContacts({
    String? search,
    String? type,
    int perPage = 50,
    int page = 1,
    String? accountNumber,
  }) {
    final q = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) q['search_text'] = s;

    final t = (type ?? '').trim();
    if (t.isNotEmpty) q['type'] = t;

    // ✅ MEMBER SCOPE for contacts (snake_case to match BE)
    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) q['account_number'] = acct;

    return _uri('zoho/v1/contacts', query: q);
  }

  /// Convenience endpoint: /contacts/customers
  Uri zohoListCustomers({
    String? search,
    int perPage = 50,
    int page = 1,
    String? accountNumber,
  }) {
    final q = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) q['search_text'] = s;

    // ✅ MEMBER SCOPE for customers list as well
    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) q['account_number'] = acct;

    return _uri('zoho/v1/contacts/customers', query: q);
  }

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

  Uri zohoListQuotes({
    int limit = 50,
    int page = 1,
    String? q,
    String? accountNumber,
  }) {
    final query = <String, String>{'limit': '$limit', 'page': '$page'};

    final qq = (q ?? '').trim();
    if (qq.isNotEmpty) query['q'] = qq;

    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) query['accountNumber'] = acct;

    return _uri('zoho/v1/quotes', query: query);
  }

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

  /// List invoices.
  /// - q: optional search string
  /// - accountNumber: optional member hard-scope
  Uri zohoListInvoices({
    int limit = 50,
    int page = 1,
    String? q,
    String? accountNumber,
  }) => _uri(
    'zoho/v1/invoices',
    query: {
      'limit': '$limit',
      'page': '$page',
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (accountNumber != null && accountNumber.trim().isNotEmpty)
        'accountNumber': accountNumber.trim(),
    },
  );

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

  /// Payments list (optionally filtered)
  /// GET /zoho/v1/payments?per_page=&page=&invoice_id=&q=&accountNumber=
  Uri zohoPaymentsList({
    int perPage = 200,
    int page = 1,
    String? invoiceId,
    String? q,
    String? accountNumber,
  }) => _uri(
    'zoho/v1/payments',
    query: {
      'per_page': '$perPage',
      'page': '$page',
      if (invoiceId != null && invoiceId.trim().isNotEmpty)
        'invoice_id': invoiceId.trim(),
      if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
      if (accountNumber != null && accountNumber.trim().isNotEmpty)
        'accountNumber': accountNumber.trim(),
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
  /// GET /zoho/v1/meta/accounts?search_text=&type=&active=
  Uri zohoMetaAccounts({String? search, String? type, bool? active}) => _uri(
    'zoho/v1/meta/accounts',
    query: {
      if (search != null && search.trim().isNotEmpty)
        'search_text': search.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (active != null) 'active': active ? 'true' : 'false',
    },
  );

  /// Optional: single account
  /// GET /zoho/v1/meta/accounts/:accountId
  Uri zohoMetaAccountById(String accountId) =>
      _uri('zoho/v1/meta/accounts/${_seg(accountId)}');
}
