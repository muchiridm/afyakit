// lib/core/api/afyakit/routes/routes_zoho.dart

part of 'routes.dart';

extension AfyaKitZohoRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // 💼 Zoho OAuth callback (core; not tenant-scoped)
  // ─────────────────────────────────────────────

  Uri zohoOAuthCallback() => _uriCore('zoho/oauth/callback');

  // ─────────────────────────────────────────────
  // 💼 Zoho Books (tenant-scoped; authenticated)
  // ─────────────────────────────────────────────

  /// NOTE: Zoho Books uses `search_text` (not `search`) for list filters.
  Uri zohoListContacts({
    String? search,
    String? type,
    int limit = 50,
    int page = 1,
  }) => _uri(
    'zoho/v1/contacts',
    query: {
      if (search != null && search.trim().isNotEmpty)
        'search_text': search.trim(),
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      'limit': '$limit',
      'page': '$page',
    },
  );

  /// NOTE: keep consistent with Zoho param naming.
  Uri zohoListCustomers({String? search, int limit = 50, int page = 1}) => _uri(
    'zoho/v1/contacts/customers',
    query: {
      if (search != null && search.trim().isNotEmpty)
        'search_text': search.trim(),
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
