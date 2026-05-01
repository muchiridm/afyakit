part of 'routes.dart';

extension AfyaKitRetailRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 🛍️ Retail contacts / quotes / invoices / payments
  // ─────────────────────────────────────────────

  /// Contacts
  Uri retailListContacts({
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

    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) q['account_number'] = acct;

    return _uri('zoho/v1/contacts', query: q);
  }

  Uri retailListCustomers({
    String? search,
    int perPage = 50,
    int page = 1,
    String? accountNumber,
  }) {
    final q = <String, String>{'per_page': '$perPage', 'page': '$page'};

    final s = (search ?? '').trim();
    if (s.isNotEmpty) q['search_text'] = s;

    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) q['account_number'] = acct;

    return _uri('zoho/v1/contacts/customers', query: q);
  }

  Uri retailGetContact(String contactId) =>
      _uri('zoho/v1/contacts/${_seg(contactId)}');

  Uri retailCreateContact() => _uri('zoho/v1/contacts');

  Uri retailUpdateContact(String contactId) =>
      _uri('zoho/v1/contacts/${_seg(contactId)}');

  Uri retailDeleteContact(String contactId) =>
      _uri('zoho/v1/contacts/${_seg(contactId)}');

  // ─────────────────────────────────────────────
  // Quotes
  // ─────────────────────────────────────────────

  Uri retailListQuotes({
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

  Uri retailGetQuote(String quoteId) => _uri('zoho/v1/quotes/${_seg(quoteId)}');

  Uri retailCreateQuote() => _uri('zoho/v1/quotes');

  Uri retailUpdateQuote(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}');

  Uri retailDeleteQuote(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}');

  Uri retailQuotePdf(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/pdf');

  Uri retailSendQuote(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/email');

  Uri retailMarkQuoteSent(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/status/sent');

  Uri retailConvertQuoteToInvoice(String quoteId) =>
      _uri('zoho/v1/quotes/${_seg(quoteId)}/convert-to-invoice');

  // ─────────────────────────────────────────────
  // Invoices
  // ─────────────────────────────────────────────

  Uri retailListInvoices({
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

  Uri retailGetInvoice(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}');

  Uri retailUpdateInvoice(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}');

  Uri retailInvoicePdf(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}/pdf');

  Uri retailSendInvoice(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}/email');

  Uri retailMarkInvoiceSent(String invoiceId) =>
      _uri('zoho/v1/invoices/${_seg(invoiceId)}/status/sent');

  // ─────────────────────────────────────────────
  // Payments
  // ─────────────────────────────────────────────

  Uri retailInvoicePayments(
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

  Uri retailPaymentsList({
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

  Uri retailPaymentsCreate() => _uri('zoho/v1/payments');

  Uri retailPaymentsGet(String paymentId) =>
      _uri('zoho/v1/payments/${_seg(paymentId)}');

  Uri retailPaymentsUpdate(String paymentId) =>
      _uri('zoho/v1/payments/${_seg(paymentId)}');

  Uri retailPaymentsDelete(String paymentId) =>
      _uri('zoho/v1/payments/${_seg(paymentId)}');

  // ─────────────────────────────────────────────
  // M-Pesa
  // ─────────────────────────────────────────────

  /// POST /api/:tenantId/mpesa/stk/initiate
  Uri retailMpesaStkInitiate() => _uri('mpesa/stk/initiate');

  /// GET /api/:tenantId/mpesa/payments/:paymentId
  Uri retailMpesaPaymentStatus(String paymentId) =>
      _uri('mpesa/payments/${_seg(paymentId)}');

  // ─────────────────────────────────────────────
  // Retail meta
  // ─────────────────────────────────────────────

  Uri retailMetaAccounts({String? search, String? type, bool? active}) => _uri(
    'zoho/v1/meta/accounts',
    query: {
      if (search != null && search.trim().isNotEmpty)
        'search_text': search.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (active != null) 'active': active ? 'true' : 'false',
    },
  );

  Uri retailMetaAccountById(String accountId) =>
      _uri('zoho/v1/meta/accounts/${_seg(accountId)}');
}
