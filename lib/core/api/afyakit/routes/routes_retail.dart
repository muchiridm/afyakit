// lib/core/api/afyakit/routes/routes_retail.dart

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

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) q[key] = v;
    }

    add('search_text', search);
    add('type', type);

    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) {
      // BE requires explicit account scoping for staff.
      q['scope'] = 'account';
      q['account_number'] = acct;
    }

    return _uri('zoho/v1/contacts', query: q);
  }

  Uri retailListCustomers({
    String? search,
    int perPage = 50,
    int page = 1,
    String? accountNumber,
  }) {
    final q = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) q[key] = v;
    }

    add('search_text', search);

    final acct = (accountNumber ?? '').trim();
    if (acct.isNotEmpty) {
      // BE requires explicit account scoping for staff.
      q['scope'] = 'account';
      q['account_number'] = acct;
    }

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
    String? customerId,
  }) {
    final query = <String, String>{'limit': '$limit', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('q', q);
    add('accountNumber', accountNumber);

    // Backend expects snake_case.
    add('customer_id', customerId);

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
    String? customerId,

    // Clinical / insurance claim context.
    //
    // These are important because insurance invoices may be addressed to the
    // insurer, not the patient. The backend uses these to search invoice
    // custom fields such as cf_patient_no and cf_claim_pack_id.
    String? patientId,
    String? patientNo,
    String? claimPackId,
    String? membershipId,
    String? prescriptionId,
  }) {
    final query = <String, String>{'limit': '$limit', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('q', q);

    // Prefer Zoho customer/contact id when available.
    // Backend expects snake_case.
    add('customer_id', customerId);

    // Fallback only. Avoid sending this if customerId exists from the caller.
    if ((customerId ?? '').trim().isEmpty) {
      add('accountNumber', accountNumber);
    }

    add('patient_id', patientId);
    add('patient_no', patientNo);
    add('claim_pack_id', claimPackId);
    add('membership_id', membershipId);
    add('prescription_id', prescriptionId);

    return _uri('zoho/v1/invoices', query: query);
  }

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
    int perPage = 100,
    int page = 1,
  }) {
    final id = invoiceId.trim();

    return _uri(
      'zoho/v1/payments/invoice/${_seg(id)}',
      query: <String, String>{'per_page': '$perPage', 'page': '$page'},
    );
  }

  Uri retailPaymentsList({
    int perPage = 200,
    int page = 1,
    String? invoiceId,
    String? q,
    String? accountNumber,
  }) {
    final query = <String, String>{'per_page': '$perPage', 'page': '$page'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('invoice_id', invoiceId);
    add('q', q);
    add('accountNumber', accountNumber);

    return _uri('zoho/v1/payments', query: query);
  }

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

  Uri retailMpesaStkInitiate() => _uri('mpesa/stk/initiate');

  Uri retailMpesaPaymentStatus(String paymentId) =>
      _uri('mpesa/payments/${_seg(paymentId)}');

  // ─────────────────────────────────────────────
  // Retail meta
  // ─────────────────────────────────────────────

  Uri retailMetaAccounts({String? search, String? type, bool? active}) {
    final query = <String, String>{};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('search_text', search);
    add('type', type);

    if (active != null) {
      query['active'] = active ? 'true' : 'false';
    }

    return _uri('zoho/v1/meta/accounts', query: query);
  }

  Uri retailMetaAccountById(String accountId) =>
      _uri('zoho/v1/meta/accounts/${_seg(accountId)}');

  // ─────────────────────────────────────────────
  // DawaIndex retail catalog
  // ─────────────────────────────────────────────

  Uri retailDiSalesTiles({
    String? q,
    String? form,
    int limit = 50,
    int offset = 0,
  }) {
    final query = <String, String>{'limit': '$limit', 'offset': '$offset'};

    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('q', q);
    add('form', form);

    return _uri('dawaindex/v1/sales/tiles', query: query);
  }
}
