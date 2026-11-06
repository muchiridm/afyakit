part of 'routes.dart';

/// Retail, billing, payments and catalog API routes.
///
/// Native Contacts are managed through the records API. Zoho Books uses
/// app-scoped contact mapping internally; no Zoho Contacts picker endpoints.
extension AfyaKitRetailRoutes on AfyaKitRoutes {
  // ─────────────────────────────────────────────
  // Quotes
  // ─────────────────────────────────────────────
  Uri retailListQuotes({
    int limit = 50,
    int page = 1,
    String? q,
    String? accountNumber,
    String? customerId,
    String? status,
    String? scope,
  }) {
    final query = <String, String>{'limit': '$limit', 'page': '$page'};
    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('q', q);
    add('status', status);
    if (scope != null && scope.trim().isNotEmpty) {
      final value = scope.trim().toLowerCase();
      if (value != 'all' && value != 'mine') {
        throw ArgumentError.value(scope, 'scope', 'Expected all or mine');
      }
      query['scope'] = value;
    }
    add('accountNumber', accountNumber);
    // Legacy/accounting filter. The backend expects snake_case.
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
    // Canonical clinical recipient identity is profileId/profile_id.
    // patientNo remains available for existing Zoho/insurer-facing fields.
    String? profileId,
    String? patientNo,
    String? claimPackId,
    String? membershipId,
    String? prescriptionId,
    String? status,
  }) {
    final query = <String, String>{'limit': '$limit', 'page': '$page'};
    void add(String key, String? value) {
      final v = (value ?? '').trim();
      if (v.isNotEmpty) query[key] = v;
    }

    add('q', q);
    add('status', status);
    // Accounting customer_id remains a Zoho customer ID for legacy filters.
    add('customer_id', customerId);
    // Preserve the existing backend fallback filter behaviour.
    if ((customerId ?? '').trim().isEmpty) {
      add('accountNumber', accountNumber);
    }
    add('profile_id', profileId);
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

  /// The backend deliberately returns HTTP 410 for GET /zoho/v1/payments.
  /// List invoices first, then call retailInvoicePayments(invoiceId).
  @Deprecated('Use retailInvoicePayments(invoiceId) instead.')
  Uri retailPaymentsList({
    int perPage = 200,
    int page = 1,
    String? invoiceId,
    String? q,
    String? accountNumber,
  }) {
    throw UnsupportedError(
      'General Zoho payment listing is disabled (HTTP 410). '
      'Use retailInvoicePayments(invoiceId).',
    );
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
  /// POST; canonical tenant M-Pesa payment initiation.
  Uri retailMpesaInitiatePayment() => _uri('mpesa/payments/initiate');

  /// POST; supported alias retained for existing callers.
  Uri retailMpesaStkInitiate() => _uri('mpesa/stk/initiate');
  Uri retailMpesaPaymentStatus(String paymentId) =>
      _uri('mpesa/payments/${_seg(paymentId)}');

  // ─────────────────────────────────────────────
  // Retail meta
  // ─────────────────────────────────────────────
  /// GET /zoho/v1/meta/accounts — only `type` is accepted by the backend.
  /// Keep optional old arguments for call-site compatibility, but reject them
  /// rather than pretending the server performs unsupported filtering.
  Uri retailMetaAccounts({String? search, String? type, bool? active}) {
    if (search != null && search.trim().isNotEmpty) {
      throw UnsupportedError('Zoho meta/accounts does not support search.');
    }
    if (active != null) {
      throw UnsupportedError('Zoho meta/accounts does not support active.');
    }
    return _uri(
      'zoho/v1/meta/accounts',
      query: {if (type != null && type.trim().isNotEmpty) 'type': type.trim()},
    );
  }

  /// No GET /zoho/v1/meta/accounts/:accountId exists in the supplied router.
  @Deprecated('Fetch the account list and select by ID locally.')
  Uri retailMetaAccountById(String accountId) {
    throw UnsupportedError(
      'Zoho meta account detail endpoint is not registered.',
    );
  }

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
